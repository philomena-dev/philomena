defmodule Philomena.SpoilerExecutor do
  alias Philomena.Elasticsearch
  alias Philomena.Images.Query
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  import Ecto.Query
  import Philomena.Search.String

  @doc """
  Compile a filter's spoiler context for the purpose of executing it as
  a spoiler. This logic is different from filter execution because it
  tags query leaves with relevant information about which aspect of the
  spoiler they match (tag match, complex filter match).
  """
  @spec compile_spoiler(map(), map()) :: map()
  def compile_spoiler(user, filter) do
    spoilered_tags =
      Enum.map(filter.spoilered_tag_ids, fn id ->
        %{term: %{tag_id: id}, _name: Integer.to_string(id)}
      end)

    spoilered_complex =
      user
      |> invalid_filter_guard(filter.spoilered_complex_str)
      |> Map.put(:_name, "complex")

    %{
      bool: %{
        should: [spoilered_complex | spoilered_tags]
      }
    }
  end

  @doc """
  Execute a spoiler previously compiled by compile_spoiler/2 on the given
  set of images. Returns a maps which maps image hits to the Tag object(s)
  the spoiler matched, or the atom :complex if the complex spoiler matched
  instead of any tag object.
  """
  @spec execute_spoiler(map(), list()) :: %{optional(integer()) => [map()] | :complex}
  def execute_spoiler(compiled, images) do
    image_ids = %{
      terms: %{id: extract_ids(images)}
    }

    test_query = %{
      bool: %{
        must: [compiled, image_ids],
      }
    }

    results = Elasticsearch.search_results(Image, test_query)

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
      |> Enum.flat_map(fn {_id, hit} -> hit["matched_queries"] end)
      |> Enum.uniq()

    Tag
    |> where([t], t.id in ^hit_tag_ids)
    |> Repo.all()
    |> Map.new(&{Integer.to_string(&1.id), &1})
  end

  # Create a map key for the response of execute_spoiler/2. Determines
  # the reason an image was in this response.
  @spec filter_reason({integer(), map()}, map()) :: {integer(), [map()] | :complex}
  defp filter_reason({id, hit}, tags) do
    tags
    |> Map.take(hit["matched_queries"])
    |> Enum.sort(&tag_sort/2)
    |> case do
      [] ->
        {id, :complex}

      matched_tags ->
        matched_tags
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
end
