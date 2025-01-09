defmodule PhilomenaQuery.Cursor do
  alias PhilomenaQuery.Search
  alias Philomena.Repo
  import Ecto.Query

  @typedoc """
  The underlying cursor type, which contains the ordered sort field values
  of a document.
  """
  @type cursor :: [integer() | binary() | boolean()]

  @typedoc """
  A mapping of document IDs to cursors.
  """
  @type cursor_map :: %{integer() => cursor()}

  @doc """
  Execute search with optional input cursor, and return results as tuple of
  `{results, cursors}`.

  ## Example

      iex> search_records(
      ...>   %{query: ..., sort: [%{created_at: :desc}, %{id: :desc}]}
      ...>   Image
      ...> )
      {%Scrivener.Page{entries: [%Image{id: 1}, ...]},
       %{1 => [1325394000000, 1], ...}}

  """
  @spec search_records(Search.search_definition(), Search.queryable(), search_after :: term()) ::
          {Scrivener.Page.t(), cursor_map()}
  def search_records(search_definition, queryable, search_after) do
    search_definition = search_after_definition(search_definition, search_after)
    page = Search.search_records_with_hits(search_definition, queryable)

    {records, cursors} =
      Enum.map_reduce(page, %{}, fn {record, hit}, cursors ->
        sort = Map.fetch!(hit, "sort")

        {record, Map.put(cursors, record.id, sort)}
      end)

    {Map.put(page, :entries, records), cursors}
  end

  @doc """
  Return page of records and cursors map based on sort.

  ## Example

      iex> paginate(Forum, [page_size: 25], ["dis", 3], asc: :name, asc: :id)
      %{4 => ["Generals", 4]}

  """
  @spec paginate(
          Ecto.Query.t(),
          scrivener_opts :: any(),
          search_after :: term(),
          sorts :: Keyword.t()
        ) :: {Scrivener.Page.t(), cursor_map()}
  def paginate(query, pagination, search_after, sorts) do
    total_entries = Repo.aggregate(query, :count)
    pagination = Keyword.merge(pagination, options: [total_entries: total_entries])

    records =
      query
      |> order_by(^sorts)
      |> search_after_query(search_after, sorts)
      |> Repo.paginate(pagination)

    fields = Keyword.values(sorts)

    cursors =
      Enum.reduce(records, %{}, fn record, cursors ->
        field_values = Enum.map(fields, &Map.fetch!(record, &1))
        Map.put(cursors, record.id, field_values)
      end)

    {records, cursors}
  end

  @spec search_after_definition(Search.search_definition(), term()) :: Search.search_definition()
  defp search_after_definition(search_definition, search_after) do
    search_after
    |> permit_search_after()
    |> case do
      [] ->
        search_definition

      search_after ->
        update_in(search_definition.body, &Map.put(&1, :search_after, search_after))
    end
  end

  @spec search_after_query(Ecto.Query.t(), term(), Keyword.t()) :: Ecto.Query.t()
  defp search_after_query(query, search_after, sorts) do
    search_after = permit_search_after(search_after)
    combined = Enum.zip(sorts, search_after)

    case combined do
      [_some | _rest] = values ->
        or_clauses = dynamic([], false)

        {or_clauses, _} =
          Enum.reduce(values, {or_clauses, []}, fn {{sd, col}, value}, {next, equal_parts} ->
            # more specific column has next value
            and_clauses =
              if sd == :asc do
                dynamic([s], field(s, ^col) > ^value)
              else
                dynamic([s], field(s, ^col) < ^value)
              end

            # and
            and_clauses =
              Enum.reduce(equal_parts, and_clauses, fn {col, value}, rest ->
                # less specific columns are equal
                dynamic([s], field(s, ^col) == ^value and ^rest)
              end)

            {dynamic(^next or ^and_clauses), equal_parts ++ [{col, value}]}
          end)

        where(query, ^or_clauses)

      _ ->
        query
    end
  end

  # Validate that search_after values are only strings, numbers, and bools
  defp permit_search_after(search_after) do
    search_after
    |> permit_list()
    |> Enum.flat_map(&permit_value/1)
  end

  defp permit_list(value) when is_list(value), do: value
  defp permit_list(_value), do: []

  defp permit_value(value) when is_binary(value) or is_number(value) or is_boolean(value),
    do: [value]

  defp permit_value(_value), do: []
end
