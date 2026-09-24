defmodule Philomena.Workers.TagReindexJob do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), integer()) :: Multi.t()
  def put_enqueue(%Multi{} = multi, tag_id) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, %{tag_id: tag_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tag_id" => tag_id}}) do
    Tags.perform_reindex_images(tag_id)
  end
end
