defmodule Philomena.UserUnvoteWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserDownvoteWipe

  @spec enqueue(integer(), boolean()) :: :ok
  def enqueue(user_id, votes_and_faves_too?) do
    Philomena.JobQueue.enqueue(__MODULE__, %{
      user_id: user_id,
      votes_and_faves_too?: votes_and_faves_too?
    })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "votes_and_faves_too?" => votes_and_faves_too?}
      }) do
    UserDownvoteWipe.perform(user_id, votes_and_faves_too?)
  end
end
