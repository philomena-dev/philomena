defmodule PhilomenaQuery.SearchHelpers do
  @moduledoc """
  Helpers for tests that exercise OpenSearch-backed behavior.

  Tests hit the real OpenSearch instance from the compose stack, namespaced
  away from development data by the `:opensearch_index_prefix` set in
  `config/test.exs` (`"test_"`). The SQL sandbox does not roll indexes
  back, so search-backed tests must:

    * be tagged `@moduletag :search` and use `async: false` (indexes are
      shared across the test run),
    * recreate the indexes they read in `setup` with `recreate_index!/1`,
    * index their fixtures explicitly (fixture inserts only enqueue dead
      Exq jobs) with `reindex_all!/1` or `index_documents!/2` before
      querying.

  ## Example

      setup do
        SearchHelpers.recreate_index!(Image)
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
  Drop and recreate the index for `schema`, leaving it empty with a fresh
  mapping.
  """
  def recreate_index!(schema) do
    Search.delete_index!(schema)
    Search.create_index!(schema)
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
