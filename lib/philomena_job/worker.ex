defmodule PhilomenaJob.Worker do
  @moduledoc false

  alias PhilomenaJob.Listener.Server, as: ListenerServer
  alias PhilomenaJob.Semaphore.Server, as: SemaphoreServer
  use GenServer

  @doc """
  Notify the given worker that work may be available.
  """
  def notify(name) do
    GenServer.cast(name, :check_work)
  end

  defstruct semaphore: nil,
            listener: nil,
            processor: nil,
            opts: nil

  @doc false
  def init(opts) do
    state = %__MODULE__{
      semaphore: Keyword.fetch!(opts, :semaphore),
      listener: Keyword.fetch!(opts, :listener),
      processor: Keyword.fetch!(opts, :processor),
      opts: Keyword.drop(opts, [:semaphore, :listener, :processor])
    }

    # Start listening for events.
    ListenerServer.link_worker(state.listener, state.processor.channel())

    # Check for new work.
    {:ok, check_work(state)}
  end

  @doc false
  def handle_cast(:check_work, %__MODULE__{} = state) do
    {:noreply, check_work(state)}
  end

  defp check_work(%__MODULE__{} = state) do
    # We have just started or received notification that work may be available.
    processor = state.processor
    opts = state.opts

    # Keep calling check_work until we run out of work.
    cycle(fn ->
      SemaphoreServer.run(state.semaphore, fn ->
        processor.check_work(opts)
      end)
    end)

    state
  end

  defp cycle(callback) do
    if callback.() do
      :ok
    else
      cycle(callback)
    end
  end
end
