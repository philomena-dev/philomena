defmodule Philomena.TagAliasWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), function(), function()) :: Multi.t()
  def put_enqueue(%Multi{} = multi, tag_id, target_tag_id)
      when is_function(tag_id, 1) and is_function(target_tag_id, 1) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, fn changes ->
      %{
        tag_id: tag_id.(changes),
        target_tag_id: target_tag_id.(changes)
      }
    end)
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
