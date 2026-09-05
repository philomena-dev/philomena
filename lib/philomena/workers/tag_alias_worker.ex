defmodule Philomena.TagAliasWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags

  @spec enqueue(integer(), integer()) :: :ok
  def enqueue(tag_id, target_tag_id) do
    Philomena.JobQueue.enqueue(__MODULE__, %{tag_id: tag_id, target_tag_id: target_tag_id})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tag_id" => tag_id, "target_tag_id" => target_tag_id}}) do
    case Tags.perform_alias(tag_id, target_tag_id) do
      {:error, :stale_target} ->
        {:cancel, :stale_target}

      result ->
        result
    end
  end
end
