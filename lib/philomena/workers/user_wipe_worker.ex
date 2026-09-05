defmodule Philomena.UserWipeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserWipe

  @spec enqueue(integer()) :: :ok
  def enqueue(user_id) do
    Philomena.JobQueue.enqueue(__MODULE__, %{user_id: user_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    UserWipe.perform(user_id)
  end
end
