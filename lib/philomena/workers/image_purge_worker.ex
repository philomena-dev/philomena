defmodule Philomena.ImagePurgeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Images

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"files" => files}}) do
    Images.perform_purge(files)
  end
end
