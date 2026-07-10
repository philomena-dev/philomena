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
    * clear the indexes they read in `setup` with
      `PhilomenaQuery.Search.clear_index!/1`,
    * index their fixtures explicitly (fixture inserts only enqueue dead
      Exq jobs) with `reindex_all!/1` before querying.

  ## Example

      setup do
        Search.clear_index!(Image)
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
  alias PhilomenaQuery.Search

  @doc """
  Drop and recreate every searchable index, so each `mix test` run starts from
  the current mappings. Called once from `test_helper.exs`; per-test isolation
  is `PhilomenaQuery.Search.clear_index!/1` from there on.

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
  Index every row of `schema` visible to the current SQL sandbox, then
  refresh so documents are immediately searchable.

  There is deliberately no single-record variant: `Search.index_document/2`
  serializes through `as_json/1`, which walks associations, so it only accepts
  records loaded with that schema's `indexing_preloads/0`. Going through
  `reindex_schema/2` is what applies them. Tables are tiny under the sandbox,
  so a full rescan costs ~4 ms on an empty table.
  """
  def reindex_all!(schema) do
    :ok = SearchIndexer.reindex_schema(schema, maintenance: false)
    Search.refresh_index!(schema)
  end
end
