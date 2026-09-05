defmodule Philomena.ImagePurgeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Images

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(files) do
    Images.perform_purge(files)
  end
end
