defmodule PhilomenaQuery.SearchHelpers do
  @moduledoc """
  Helpers for tests that exercise OpenSearch-backed behavior.

  Tests hit the real OpenSearch instance from the compose stack, namespaced
  away from development data by the `:opensearch_index_prefix` set in
  `config/test.exs` (`"test_"`). Every searchable index is created once per
  `mix test` run, with the current mappings, by `create_all_indexes!/0` in
  `test/test_helper.exs`. The SQL sandbox does not roll indexes back, so
  search-backed tests must:

    * be tagged `@moduletag :search` and use `async: false` (indexes are
      shared across the test run),
    * clear the indexes they read in `setup` with `clear_index!/1`,
    * index their fixtures explicitly (fixture inserts only enqueue dead
      Exq jobs) with `reindex_all!/1` or `index_documents!/2` before
      querying.

  ## Example

      setup do
        SearchHelpers.clear_index!(Image)
        :ok
      end

      test "lists images", %{conn: conn} do
        image = image_fixture()
        SearchHelpers.reindex_all!(Image)

        conn = get(conn, ~p"/search?q=safe")
        ...
      end

  """

  alias Philomena.SearchIndexer
  alias Philomena.SearchPolicy
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.Search.Client

  @doc """
  Drop and recreate every searchable index, so each `mix test` run starts from
  the current mappings. Called once from `test_helper.exs`; per-test isolation
  is `clear_index!/1` from there on.

  The schema list comes from `SearchIndexer.schemas/0` rather than a local copy,
  so a newly searchable schema is picked up here automatically.
  """
  def create_all_indexes! do
    Enum.each(SearchIndexer.schemas(), fn schema ->
      Search.delete_index!(schema)
      Search.create_index!(schema)
    end)
  end

  @doc """
  Remove every document from `schema`'s index, leaving the mapping intact, and
  refresh so the emptied index is immediately visible to search.

  This is the per-test isolation primitive. Dropping and recreating the index
  instead is ~100x slower (a cluster-metadata operation) and nothing in the
  suite needs a fresh mapping mid-run.
  """
  def clear_index!(schema) do
    url =
      "#{SearchPolicy.opensearch_url()}/#{Search.index_name(schema)}" <>
        "/_delete_by_query?refresh=true&conflicts=proceed"

    {:ok, %{status: 200}} = Client.post(url, %{query: %{match_all: %{}}})
    :ok
  end

  @doc """
  Index every row of `schema` visible to the current SQL sandbox, then
  refresh so documents are immediately searchable.
  """
  def reindex_all!(schema) do
    :ok = SearchIndexer.reindex_schema(schema, maintenance: false)
    refresh_index!(schema)
  end

  @doc """
  Index the given `records` (structs of `schema`), then refresh so they are
  immediately searchable.
  """
  def index_documents!(records, schema) do
    Enum.each(records, &Search.index_document(&1, schema))
    refresh_index!(schema)
  end

  @doc """
  Force a refresh of the index for `schema`. OpenSearch only exposes new
  documents to search after a refresh, which otherwise happens on a ~1s
  interval — without this, tests would race it.
  """
  def refresh_index!(schema) do
    url = "#{SearchPolicy.opensearch_url()}/#{Search.index_name(schema)}/_refresh"
    {:ok, %{status: 200}} = Client.post(url, %{})
    :ok
  end
end
