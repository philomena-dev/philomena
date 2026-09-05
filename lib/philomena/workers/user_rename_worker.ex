defmodule Philomena.UserRenameWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users

  @spec enqueue(String.t(), String.t()) :: :ok
  def enqueue(old_name, new_name) do
    Philomena.JobQueue.enqueue(__MODULE__, %{old_name: old_name, new_name: new_name})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"old_name" => old_name, "new_name" => new_name}}) do
    Users.perform_rename(old_name, new_name)
  end
end
