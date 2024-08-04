defmodule PhilomenaJob.Supervisor do
  @moduledoc """
  Main supervisor for jobs processing.

  Supported options:
  - `:max_concurrency`: the maximum number of processors which can run in parallel. Required.
    This is global across all processors specified by this supervisor instance.
    Lowering the maximum concurrency delays processors until the concurrency drops.
  - `:repo_url`: the Ecto URL to the database. Can be fetched from application env. Required.
  - `:processors`: A list of processor modules to create worker processes for. Required.
  - `:name`: the global name for this supervisor instance. Required.

  Processor modules should implement the processor behaviour. See the `PhilomenaJob.Processor`
  documentation for more information on required callbacks.

  ## Example

      children = [
        {PhilomenaJob.Supervisor,
           max_concurrency: System.schedulers_online(),
           repo_url: Application.get_env(:philomena, Philomena.Repo)[:url],
           processors: [
             CommentIndexUpdater,
             FilterIndexUpdater,
             GalleryIndexUpdater,
             ImageIndexUpdater,
             PostIndexUpdater,
             ReportIndexUpdater,
             TagIndexUpdater
           ],
           name: IndexWorkSupervisor
         }
      ]

      Supervisor.start_link(children, opts)

  """

  alias PhilomenaJob.Semaphore.Server, as: SemaphoreServer
  alias PhilomenaJob.Listener.Server, as: ListenerServer
  alias PhilomenaJob.NotifierServer
  alias PhilomenaJob.Worker

  @doc false
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: Module.concat(__MODULE__, name),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc false
  def start_link(opts) do
    processors = Keyword.fetch!(opts, :processors)
    name = Keyword.fetch!(opts, :name)

    # Start the main supervisor.
    {:ok, main_sup} =
      Supervisor.start_link(
        [],
        strategy: :one_for_one,
        auto_shutdown: :any_significant,
        name: name
      )

    # Start all three significant processes.
    # If any of these exit, the supervisor exits.
    opts =
      opts
      |> start_named_child(name, :notifier, NotifierServer)
      |> start_named_child(name, :semaphore, SemaphoreServer)
      |> start_named_child(name, :listener, ListenerServer)

    # Start workers. These can restart automatically.
    for processor <- processors do
      opts = Keyword.merge(opts, processor: processor)

      Supervisor.start_child(name, {Worker, opts})
    end

    # Return the main supervisor.
    {:ok, main_sup}
  end

  defp start_named_child(opts, sup, name, child_module) do
    {:ok, child} = Supervisor.start_child(sup, {child_module, opts})

    Keyword.merge(opts, [{name, child}])
  end
end
