defmodule Philomena.UserWipeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.UserWipe

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    UserWipe.perform(user_id)
  end
end
