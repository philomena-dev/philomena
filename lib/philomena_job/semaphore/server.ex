defmodule PhilomenaJob.Semaphore.Server do
  @moduledoc """
  A counting semaphore.

  This is used to limit the concurrency of a potentially large group of processes by calling
  `acquire/1` or `run/1` - only up to the number of processes indicated by the startup value
  are allowed to run concurrently.

  A supervision tree example:

      children = [
        {PhilomenaJob.Semaphore.Server, name: WorkerSemaphore, max_concurrency: 16}
      ]

  """

  alias PhilomenaJob.Semaphore.State
  use GenServer, restart: :temporary, significant: true

  @doc """
  Wraps the given callback with an acquire before the callback and a release after running
  the callback.

  Returns the return value of the callback.

  See `acquire/1` and `release/1` for additional details.

  ## Example

      iex> Semaphore.run(WorkerSemaphore, fn -> check_work(state) end)
      true

  """
  def run(name, callback) do
    acquire(name)
    ret = callback.()
    release(name)
    ret
  end

  @doc """
  Decrement the semaphore with the given name.

  This either returns immediately with the semaphore value acquired, or blocks indefinitely until
  sufficient other processes have released their holds on the semaphore to allow a new one to
  acquire.

  Processes which acquire the semaphore are monitored, and exits with an acquired value trigger
  automatic release, so exceptions will not break the semaphore.

  ## Example

      iex> Semaphore.acquire(semaphore)
      :ok

  """
  def acquire(name) do
    :ok = GenServer.call(name, :acquire, :infinity)
  end

  @doc """
  Increment the semaphore with the given name.

  This releases the hold given by the current process and allows another process to begin running.

  ## Example

      iex> Semaphore.release(semaphore)
      :ok

  """
  def release(name) do
    :ok = GenServer.call(name, :release, :infinity)
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  @impl true
  def init(opts) do
    {:ok, State.new(opts)}
  end

  @doc false
  @impl true
  def handle_call(message, from, state)

  def handle_call(:acquire, from, state) do
    case State.add_pending_process(state, from) do
      {:ok, new_state} ->
        {:noreply, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:release, {pid, _}, state) do
    {:ok, new_state} = State.release_active_process(state, pid)

    {:reply, :ok, new_state}
  end

  @doc false
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:ok, state} = State.release_active_process(state, pid)

    {:noreply, state}
  end
end
