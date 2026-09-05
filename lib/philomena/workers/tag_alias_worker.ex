defmodule Philomena.TagAliasWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Tags

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(tag_id, target_tag_id) do
    Tags.perform_alias(tag_id, target_tag_id)
  end
end
