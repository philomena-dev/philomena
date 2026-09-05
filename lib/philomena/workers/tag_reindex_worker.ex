defmodule Philomena.TagReindexWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags

  @spec enqueue(integer()) :: :ok
  def enqueue(tag_id) do
    Philomena.JobQueue.enqueue(__MODULE__, %{tag_id: tag_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tag_id" => tag_id}}) do
    Tags.perform_reindex_images(tag_id)
  end
end
