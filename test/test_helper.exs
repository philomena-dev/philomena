ExUnit.start()

# Stop the advert batching server for the duration of the test run. It wakes
# every 10 seconds and calls Adverts.Recorder.run/1, which issues Repo.insert_all
# even with empty impression/click state. That write comes from a process that
# owns no sandbox connection, so with the sandbox in :manual mode it raises a
# DBConnection.OwnershipError. Terminating the child avoids the periodic noise.
# GenServer.cast to the now-dead name still returns :ok silently, so AdvertPlug's
# record_impression casts during controller tests are harmlessly dropped.
Supervisor.terminate_child(Philomena.Supervisor, Philomena.Adverts.Server)

Ecto.Adapters.SQL.Sandbox.mode(Philomena.Repo, :manual)
