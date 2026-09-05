defmodule Philomena.UserRenameWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Users

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(old_name, new_name) do
    Users.perform_rename(old_name, new_name)
  end
end
