defmodule Philomena.TagDeleteWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tag_id" => tag_id}}) do
    Tags.perform_delete(tag_id)
  end
end
