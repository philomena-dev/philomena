defmodule Philomena.Workers.ImagePurgeJob do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  alias Philomena.Images
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), (Multi.changes() -> [String.t()])) :: Multi.t()
  def put_enqueue(%Multi{} = multi, files) when is_function(files, 1) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, fn changes ->
      %{files: files.(changes)}
    end)
  end

  @spec enqueue([String.t()]) :: any()
  def enqueue(files) do
    # Legacy variation for thumbnailer.
    Philomena.JobQueue.insert(__MODULE__, %{files: files})
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"files" => files}}) do
    Images.perform_purge(files)
  end
end
