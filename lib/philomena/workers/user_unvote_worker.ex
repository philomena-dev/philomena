defmodule Philomena.UserUnvoteWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserDownvoteWipe
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), function(), boolean()) :: Multi.t()
  def put_enqueue(%Multi{} = multi, user_id, votes_and_faves_too?)
      when is_function(user_id, 1) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, fn changes ->
      %{
        user_id: user_id.(changes),
        votes_and_faves_too?: votes_and_faves_too?
      }
    end)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => user_id, "votes_and_faves_too?" => votes_and_faves_too?}
      }) do
    UserDownvoteWipe.perform(user_id, votes_and_faves_too?)
  end
end
