defmodule Philomena.SpoilerExecutor do
  alias Philomena.Elasticsearch
  alias Philomena.Images.Query
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  import Ecto.Query
  import Philomena.Search.String

  @complex_tag "complex"
  @hidden_tag "hidden"

  @doc """
  Compile a filter's spoiler context for the purpose of executing it as
  a spoiler. This logic is different from filter execution because it
  tags query leaves with relevant information about which aspect of the
  spoiler they match (tag spoiler match, complex spoiler match).
  """
  @spec compile_spoiler(map(), map()) :: map()
  def compile_spoiler(user, filter) do
    spoilered_tags =
      Enum.map(filter.spoilered_tag_ids, fn id ->
        %{term: %{tag_ids: %{value: id, _name: Integer.to_string(id)}}}
      end)

    spoilered_complex = %{
      bool: %{
        must: invalid_filter_guard(user, filter.spoilered_complex_str),
        _name: @complex_tag
      }
    }

    hides = %{
      bool: %{
        must: [
          invalid_filter_guard(user, filter.hidden_complex_str),
          %{terms: %{tag_ids: filter.hidden_tag_ids}}
        ],
        _name: @hidden_tag
      }
    }

    %{
      bool: %{
        should: [hides, spoilered_complex | spoilered_tags]
      }
    }
  end

  @doc """
  Execute a spoiler previously compiled by compile_spoiler/2 on the given
  set of images. Returns a maps which maps image hits to the Tag object(s)
  the spoiler matched, or the atom :complex if the complex spoiler matched
  instead of any tag object.
  """
  @spec execute_spoiler(map(), list()) :: %{optional(integer()) => [map()] | :complex | :hidden}
  def execute_spoiler(compiled, images) do
    image_ids = extract_ids(images)

    image_terms = %{
      terms: %{id: extract_ids(images)}
    }

    test_query = %{
      query: %{
        bool: %{
          must: [compiled, image_terms]
        }
      }
    }

    pagination_params = %{
      page_number: 1,
      page_size: length(image_ids)
    }

    results = Elasticsearch.search_results(Image, test_query, pagination_params)

    tags = extract_tags(results.entries)

    results
    |> Enum.map(&filter_reason(&1, tags))
    |> Map.new()
  end

  # Protect against an invalid query string included inside the filter
  # from raising an error up to the user.
  @spec invalid_filter_guard(map(), String.t()) :: map()
  defp invalid_filter_guard(user, search_string) do
    case Query.compile(user, normalize(search_string)) do
      {:ok, query} -> query
      _error -> %{match_all: %{}}
    end
  end

  # Extract image ids in heterogeneous format from controllers.
  @spec extract_ids([nil | map() | {map(), any()} | Enumerable.t()]) :: [integer()]
  defp extract_ids(images) do
    Enum.flat_map(images, fn
      nil -> []
      %{id: id} -> [id]
      {%{id: id}, _hit} -> [id]
      enum -> extract_ids(enum)
    end)
  end

  # Extract matched Tag objects from a list of search hits.
  #
  # The expected case of the list being empty is explored first to avoid
  # unnecessary database roundtrips.
  @spec extract_tags(list()) :: map()
  defp extract_tags(results)

  defp extract_tags([]) do
    %{}
  end

  defp extract_tags(results) do
    hit_tag_ids =
      results
      |> Enum.flat_map(fn {_id, hit} -> filter_special_matched(hit["matched_queries"]) end)
      |> Enum.uniq()

    Tag
    |> where([t], t.id in ^hit_tag_ids)
    |> Repo.all()
    |> Map.new(&{Integer.to_string(&1.id), &1})
  end

  # Create a map key for the response of execute_spoiler/2. Determines
  # the reason an image was in this response.
  @spec filter_reason({integer(), map()}, map()) :: {integer(), [map()] | :complex | :hidden}
  defp filter_reason({id, hit}, tags) do
    matched_queries = hit["matched_queries"]

    if Enum.member?(matched_queries, @hidden_tag) do
      {id, :hidden}
    else
      tags
      |> Map.take(matched_queries)
      |> Enum.sort(&tag_sort/2)
      |> case do
        [] ->
          {id, :complex}

        matched_tags ->
          {id, matched_tags}
      end
    end
  end

  # The logic for tag sorting is as follows:
  #   1. If both tags have a spoiler image, sort by images count asc
  #   2. If neither tag has a spoiler image, sort by images count desc
  #   3. Otherwise, the tag with the spoiler image takes precedence
  @spec tag_sort(map(), map()) :: boolean()
  defp tag_sort(a, b) do
    cond do
      not is_nil(a.image) and not is_nil(b.image) ->
        a.images_count <= b.images_count

      is_nil(a.image) and is_nil(b.image) ->
        b.images_count >= a.images_count

      is_nil(a.image) ->
        false

      true ->
        true
    end
  end

  # The list of matched queries may return things which do not look like
  # integer IDs and will cause Postgrex to choke; filter those out here.
  @spec filter_special_matched(list()) :: list()
  defp filter_special_matched(matched_queries) do
    Enum.filter(matched_queries, &String.match?(&1, ~r/\A\d+\z/))
  end
end
