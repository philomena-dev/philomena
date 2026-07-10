ExUnit.start()

# Stop the advert batching server for the duration of the test run. It wakes every
# 10 seconds and flushes whatever impressions AdvertPlug has cast to it through
# Adverts.Recorder.run/1. An empty flush is free (Ecto skips Repo.insert_all on an
# empty list), but as soon as a controller test renders a page carrying an advert
# the flush issues a real write - from a process that owns no sandbox connection,
# so with the sandbox in :manual mode it raises DBConnection.OwnershipError.
# Terminating the child avoids the periodic noise. GenServer.cast to the now-dead
# name still returns :ok silently, so AdvertPlug's record_impression casts during
# controller tests are harmlessly dropped.
Supervisor.terminate_child(Philomena.Supervisor, Philomena.Adverts.Server)

# Create every searchable index once, with the current mappings. Tests get
# per-test isolation from PhilomenaQuery.Search.clear_index!/1, which only
# deletes documents - dropping and recreating an index costs ~95 ms and used to
# run once per test.
PhilomenaQuery.SearchHelpers.create_all_indexes!()

Ecto.Adapters.SQL.Sandbox.mode(Philomena.Repo, :manual)
