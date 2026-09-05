defmodule Philomena.UserUnvoteWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserDownvoteWipe

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(user_id, votes_and_faves_too?) do
    UserDownvoteWipe.perform(user_id, votes_and_faves_too?)
  end
end
