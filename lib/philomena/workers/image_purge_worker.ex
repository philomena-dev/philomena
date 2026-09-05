defmodule Philomena.ImagePurgeWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Images

  @spec enqueue([String.t()]) :: :ok
  def enqueue(files) when is_list(files) do
    Philomena.JobQueue.enqueue(__MODULE__, %{files: files})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"files" => files}}) do
    Images.perform_purge(files)
  end
end
