defmodule Philomena.Images.Search do
  @moduledoc """
  Search-backed image loading, scoped to a viewer.

  Builds OpenSearch definitions for image listings by combining a query with
  the viewer's compiled filter, the deleted/hidden visibility switches, and the
  requested sort order; loads the tags a tag search names; and finds
  consecutive images for prev/next navigation.

  Query-building functions return `{definition, tags}`: an unexecuted search
  definition plus the raw `Tag` records the query names.
  Definitions are executed with `execute/2`, or batched by callers into
  `PhilomenaQuery.Search.msearch_records/1` alongside definitions for other
  schemas.
  """

  alias Philomena.Images.Image
  alias Philomena.Attribution.Actor
  alias Philomena.Images.Query
  alias Philomena.Images.Search.Scope
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  import Ecto.Query
  import Philomena.Authorization, only: [authorize: 3]

  @allowed_sort_fields ~W(
    id
    updated_at
    first_seen_at
    aspect_ratio
    faves
    downvotes
    upvotes
    width
    height
    score
    comment_count
    tag_count
    wilson_score
    pixels
    size
    duration
    hides
  )

  @order_for_dir %{
    "next" => %{"asc" => "asc", "desc" => "desc"},
    "prev" => %{"asc" => "desc", "desc" => "asc"}
  }

  @type definition :: Search.search_definition()
  @type query_result :: {definition(), [Tag.t()]}
  @type option ::
          {:pagination, map()}
          | {:sorts, (map() -> %{query: map(), sorts: list()})}
          | {:tag_names, [String.t()]}

  @doc """
  Builds the default image listing query for the viewer.

  Images uploaded less than three minutes ago (or without generated
  thumbnails) are excluded unless the viewer has turned the upload delay off;
  staff have a separate delay preference.

  Returns `{definition, tags}`.
  """
  @spec default_query(Actor.t(), Scope.t(), [option()]) :: query_result()
  # sobelow_skip ["SQL.Query"]
  def default_query(actor, scope, options \\ []) do
    body =
      if delay_home_images?(actor.user),
        do: %{
          bool: %{
            must: [%{range: %{created_at: %{lte: "now-3m"}}}],
            must_not: [%{term: %{thumbnails_generated: false}}]
          }
        },
        else: %{match_all: %{}}

    query(actor, scope, body, options)
  end

  @doc """
  Compiles a search-language string for the viewer and builds its query.

  Returns `{:ok, {definition, tags}}`, or the compiler's `{:error, msg}` for
  a malformed query.
  """
  @spec search_string(Actor.t(), Scope.t(), String.t() | nil, [option()]) ::
          {:ok, query_result()} | {:error, String.t()}
  # sobelow_skip ["SQL.Query"]
  def search_string(actor, scope, search_string, options \\ []) do
    case Query.compile_with_tag_names(search_string, user: actor.user) do
      {:ok, %{query: tree, tag_names: tag_names}} ->
        {:ok, query(actor, scope, tree, Keyword.put(options, :tag_names, tag_names))}

      {:error, _message} = error ->
        error
    end
  end

  @doc """
  Builds a query definition from an already-compiled query body.

  Options: `:pagination` overrides the scope's window; `:sorts` replaces the
  parameter-driven sort with a custom `body -> %{query:, sorts:}` function.

  Returns `{definition, tags}`.
  """
  @spec query(Actor.t(), Scope.t(), map(), [option()]) :: query_result()
  def query(actor, scope, body, options \\ []) do
    pagination = Keyword.get(options, :pagination, scope.pagination)
    sorts = Keyword.get(options, :sorts, &parse_sort(scope, &1))

    tags = options |> Keyword.get(:tag_names, []) |> load_tags()

    filters = create_filters(actor, scope)

    %{query: query, sorts: sort} = sorts.(body)

    definition =
      Search.search_definition(
        Image,
        %{
          query: %{
            bool: %{
              must: query,
              must_not: filters
            }
          },
          sort: sort
        },
        pagination
      )

    {definition, tags}
  end

  @doc """
  Executes a definition, returning the record page.

  Records are loaded with the standard listing preloads
  (`[:sources, tags: :aliases]`); pass `:preload` to override. With `hits: true`
  each record is paired with its raw hit, for listings that need sort cursors.
  """
  @spec execute(definition(), Keyword.t()) :: Enumerable.t()
  def execute(definition, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:sources, tags: :aliases])
    queryable = preload(Image, ^preloads)

    if opts[:hits] do
      Search.search_records_with_hits(definition, queryable)
    else
      Search.search_records(definition, queryable)
    end
  end

  @doc """
  Maps the "sf"/"sd" parameters onto a sort order for `query_body`.

  Unlisted or missing fields sort by `first_seen_at`; `random`/`random:seed`
  wrap the query in a seeded `function_score`; `gallery_id:n` sorts by the
  image's position in that gallery.

  Returns `%{query:, sorts:}`.
  """
  @spec parse_sort(map(), map()) :: %{query: map(), sorts: list()}
  def parse_sort(%Scope{} = scope, query_body) do
    sd = parse_sd(%{"sd" => scope.sd})

    parse_sf(%{"sf" => scope.sf}, sd, query_body)
  end

  def parse_sort(params, query_body) when is_map(params) do
    sd = parse_sd(params)

    parse_sf(params, sd, query_body)
  end

  @doc """
  Finds the image next to `image` in the listing the scope's parameters
  describe, for prev/next navigation.

  `compiled_query` is the compiled body of the listing's search query;
  `scope.rel` selects the direction and `scope.sort`
  carries the sort cursor of the current image, when present.

  Returns the `{image, hit}` pair for the neighbouring image, or `nil` at
  the end of the sequence.
  """
  @spec find_consecutive(Actor.t(), Scope.t(), Image.t(), map()) :: {Image.t(), map()} | nil
  def find_consecutive(actor, scope, image, compiled_query) do
    sf = scope.sf || "first_seen_at"

    %{query: compiled_query, sorts: sorts} = parse_sort(scope, compiled_query)

    sorts =
      sorts
      |> Enum.flat_map(&Enum.to_list/1)
      |> Enum.map(&apply_direction(&1, scope.rel))

    search_after =
      scope.sort
      |> permit_list()
      |> Enum.flat_map(&permit_value/1)
      |> default_cursors(sf, image)

    maybe_search_after(
      Image,
      %{
        query: %{
          bool: %{
            must: compiled_query,
            must_not: [%{term: %{id: image.id}} | create_filters(actor, scope)]
          }
        },
        sort: sorts,
        search_after: search_after
      },
      %{page_size: 1},
      Image,
      length(sorts) == length(search_after)
    )
    |> Enum.to_list()
    |> case do
      [] -> nil
      [next_image] -> next_image
    end
  end

  defp delay_home_images?(nil), do: true

  defp delay_home_images?(user) when user.role != "user",
    do: user.settings.staff_delay_home_images

  defp delay_home_images?(user), do: user.settings.delay_home_images

  defp create_filters(actor, scope) do
    show_hidden? = authorize(actor, :hide, %Image{}) == :ok
    del = scope.del
    hidden = scope.hidden

    [
      scope.filter
    ]
    |> maybe_show_deleted(show_hidden?, del)
    |> maybe_custom_hide(actor.user, hidden)
    |> hide_non_approved()
  end

  # The del switches are a staff tool: every viewer without the hide
  # permission gets the hidden-image exclusion no matter what the
  # parameter says, so the permission check must come before the
  # parameter match.

  defp maybe_show_deleted(filters, false, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  defp maybe_show_deleted(filters, true, "1"),
    do: filters

  defp maybe_show_deleted(filters, true, "only"),
    do: [%{term: %{hidden_from_users: false}} | filters]

  defp maybe_show_deleted(filters, true, "deleted"),
    do: [%{term: %{hidden_from_users: false}}, %{exists: %{field: :duplicate_id}} | filters]

  defp maybe_show_deleted(filters, true, _param),
    do: [%{term: %{hidden_from_users: true}} | filters]

  # Allow users to reverse the effect of hiding images,
  # if desired

  defp maybe_custom_hide(filters, %{id: _id}, true),
    do: filters

  defp maybe_custom_hide(filters, %{id: id}, _param),
    do: [%{term: %{hidden_by_user_ids: id}} | filters]

  defp maybe_custom_hide(filters, _user, _param),
    do: filters

  # Hide all images that aren't approved from all search queries.
  defp hide_non_approved(filters),
    do: [%{term: %{approved: false}} | filters]

  defp load_tags([]), do: []

  defp load_tags(tags) do
    Tag
    |> join(:left, [t], at in Tag, on: t.id == at.aliased_tag_id)
    |> where([t, at], t.name in ^tags or at.name in ^tags)
    |> preload([
      :aliases,
      :aliased_tag,
      :implied_tags,
      :implied_by_tags,
      :dnp_entries,
      :channels,
      public_links: :user,
      hidden_links: :user
    ])
    |> Repo.all()
    |> Enum.uniq_by(& &1.id)
    |> Enum.filter(&is_nil(&1.aliased_tag))
    |> Tag.display_order()
  end

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc), do: sd
  defp parse_sd(_params), do: "desc"

  defp parse_sf(%{"sf" => sf}, sd, query) when sf == "id" do
    %{query: query, sorts: [%{"id" => sd}]}
  end

  defp parse_sf(%{"sf" => sf}, sd, query) when sf in @allowed_sort_fields do
    %{query: query, sorts: [%{sf => sd}, %{"id" => sd}]}
  end

  defp parse_sf(%{"sf" => "_score"}, sd, query) do
    %{query: query, sorts: [%{"_score" => sd}, %{"id" => sd}]}
  end

  defp parse_sf(%{"sf" => "random"}, sd, query) do
    random_query(:rand.uniform(4_294_967_296), sd, query)
  end

  defp parse_sf(%{"sf" => <<"random:", seed::binary>>}, sd, query) do
    case Integer.parse(seed) do
      {seed, _rest} ->
        random_query(seed, sd, query)

      _ ->
        random_query(:rand.uniform(4_294_967_296), sd, query)
    end
  end

  defp parse_sf(%{"sf" => <<"gallery_id:", gallery::binary>>}, sd, query) do
    case Integer.parse(gallery) do
      {gallery, _rest} ->
        %{
          query: query,
          sorts: [
            %{
              "galleries.position" => %{
                order: sd,
                nested: %{
                  path: :galleries,
                  filter: %{
                    term: %{"galleries.id" => gallery}
                  }
                }
              }
            },
            %{"id" => "desc"}
          ]
        }

      _ ->
        %{query: query, sorts: []}
    end
  end

  defp parse_sf(_params, sd, query) do
    %{query: query, sorts: [%{"first_seen_at" => sd}, %{"id" => sd}]}
  end

  defp random_query(seed, sd, query) do
    %{
      query: %{
        function_score: %{
          query: query,
          random_score: %{seed: seed, field: :id},
          boost_mode: :replace
        }
      },
      sorts: [%{"_score" => sd}, %{"id" => sd}]
    }
  end

  defp maybe_search_after(module, body, options, queryable, true) do
    module
    |> Search.search_definition(body, options)
    |> Search.search_records_with_hits(queryable)
  end

  defp maybe_search_after(_module, _body, _options, _queryable, _false) do
    []
  end

  defp default_cursors([], "id", image), do: [image.id]

  defp default_cursors([], "first_seen_at", image),
    do: [image.first_seen_at |> DateTime.to_unix(:millisecond), image.id]

  defp default_cursors(list, _sf, _image), do: list

  defp apply_direction({"galleries.position", sort_body}, rel) do
    sort_body = update_in(sort_body.order, fn direction -> @order_for_dir[rel][direction] end)

    %{"galleries.position" => sort_body}
  end

  defp apply_direction({field, direction}, rel) do
    %{field => @order_for_dir[rel][direction]}
  end

  defp permit_list(value) when is_list(value), do: value
  defp permit_list(_value), do: []

  defp permit_value(value) when is_binary(value) or is_number(value), do: [value]
  defp permit_value(_value), do: []
end
