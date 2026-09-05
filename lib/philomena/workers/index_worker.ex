defmodule Philomena.IndexWorker do
  use Oban.Worker, queue: :indexing, max_attempts: 5

  @modules %{
    "Comments" => Philomena.Comments,
    "Galleries" => Philomena.Galleries,
    "Images" => Philomena.Images,
    "Posts" => Philomena.Posts,
    "Reports" => Philomena.Reports,
    "Tags" => Philomena.Tags,
    "Filters" => Philomena.Filters,
    "TagChanges" => Philomena.TagChanges,
    "Users" => Philomena.Users
  }

  @spec enqueue(String.t(), atom() | String.t(), [integer()]) :: :ok
  def enqueue(module, column, condition) when is_binary(module) and is_list(condition) do
    Philomena.JobQueue.enqueue(__MODULE__, %{
      module: module,
      column: to_string(column),
      condition: condition
    })
  end

  # Perform the queued index. Context function looks like the following:
  #
  #     def perform_reindex(column, condition) do
  #       Image
  #       |> preload(^indexing_preloads())
  #       |> where([i], field(i, ^column) in ^condition)
  #       |> Search.reindex(Image)
  #     end
  #
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"module" => module, "column" => column, "condition" => condition}
      }) do
    @modules[module].perform_reindex(String.to_existing_atom(column), condition)
  end
end
