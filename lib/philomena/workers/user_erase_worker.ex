defmodule Philomena.UserEraseWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users.Eraser
  alias Philomena.Users

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(user_id, moderator_id) do
    moderator = Users.fetch_user_for_erase!(moderator_id)
    user = Users.fetch_user_for_worker!(user_id)

    Eraser.erase_permanently!(user, moderator)
  end
end
