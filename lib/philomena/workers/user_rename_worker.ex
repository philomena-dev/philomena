defmodule Philomena.UserRenameWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), (Multi.changes() -> {String.t(), String.t()})) :: Multi.t()
  def put_enqueue(%Multi{} = multi, old_and_new_names) when is_function(old_and_new_names, 1) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, fn changes ->
      {old_name, new_name} = old_and_new_names.(changes)

      %{
        old_name: old_name,
        new_name: new_name
      }
    end)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"old_name" => old_name, "new_name" => new_name}}) do
    Users.perform_rename(old_name, new_name)
  end
end
