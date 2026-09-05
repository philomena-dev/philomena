defmodule Philomena.UserEraseWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.Eraser
  alias Philomena.Users

  @spec enqueue(integer(), integer()) :: :ok
  def enqueue(user_id, moderator_id) do
    Philomena.JobQueue.enqueue(__MODULE__, %{user_id: user_id, moderator_id: moderator_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "moderator_id" => moderator_id}}) do
    moderator = Users.fetch_user_for_erase!(moderator_id)
    user = Users.fetch_user_for_worker!(user_id)

    Eraser.erase_permanently!(user, moderator)
  end
end
