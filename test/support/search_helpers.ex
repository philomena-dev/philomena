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

  # `Search.delete_index!/1` and `Search.create_index!/1` return bare
  # `PhilomenaQuery.Search.Client` results: `{:ok, response}` for ANY response
  # status, `{:error, exception}` only for transport failures. Neither is
  # checked by the caller, so a failed creation here would go unnoticed until
  # the sync (`:search`-tagged) test phase, where every search test then fails
  # with a baffling `index_not_found_exception`. Retry transient errors (in CI
  # the suite boots seconds after a heavy full compile), and raise with the
  # underlying response if recreation never succeeds.
  @recreate_attempts 10
  @recreate_backoff_ms 3_000

  @doc """
  Drop and recreate every searchable index, so each `mix test` run starts from
  the current mappings. Called once from `test_helper.exs`; per-test isolation
  is `PhilomenaQuery.Search.clear_index!/1` from there on.

  The schema list comes from `SearchIndexer.schemas/0` rather than a local copy,
  so a newly searchable schema is picked up here automatically.
  """
  def create_all_indexes! do
    Enum.each(SearchIndexer.schemas(), &recreate_index!(&1, 1))
  end

  defp recreate_index!(schema, attempt) do
    case try_recreate_index(schema) do
      :ok ->
        :ok

      {:error, error} when attempt < @recreate_attempts ->
        IO.puts(
          :stderr,
          "Recreating the #{inspect(schema)} search index failed " <>
            "(attempt #{attempt}/#{@recreate_attempts}, retrying): #{inspect(error)}"
        )

        Process.sleep(@recreate_backoff_ms)
        recreate_index!(schema, attempt + 1)

      {:error, error} ->
        raise "Could not recreate the #{inspect(schema)} search index: #{inspect(error)}"
    end
  end

  defp try_recreate_index(schema) do
    with {:ok, %{status: status}} when status in [200, 404] <- Search.delete_index!(schema),
         {:ok, %{status: 200}} <- Search.create_index!(schema) do
      :ok
    else
      error -> {:error, error}
    end
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
