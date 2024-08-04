defmodule PhilomenaJob.Semaphore.State do
  @doc """
  Internal semaphore state.
  """

  defstruct active_processes: %{},
            pending_processes: %{},
            max_concurrency: nil,
            demonitor: nil,
            monitor: nil,
            reply: nil

  @doc """
  Create a new instance of the internal semaphore state.

  Supported options:
  - `:max_concurrency`: the maximum number of processes which can be active. Required.
  - `:demonitor`: callback to de-monitor a process. Optional, defaults to `Process.demonitor/1`.
  - `:monitor`: callback to monitor a process. Optional, defaults to `Process.monitor/1`.
  - `:reply`: callback to reply to a process. Optional, defaults to `GenServer.reply/2`.

  ## Examples

      iex> State.new(max_concurrency: System.schedulers_online())
      %State{}

  """
  def new(opts) do
    max_concurrency = Keyword.fetch!(opts, :max_concurrency)
    demonitor = Keyword.get(opts, :demonitor, &Process.demonitor/1)
    monitor = Keyword.get(opts, :monitor, &Process.monitor/1)
    reply = Keyword.get(opts, :reply, &GenServer.reply/2)

    %__MODULE__{
      max_concurrency: max_concurrency,
      demonitor: demonitor,
      monitor: monitor,
      reply: reply
    }
  end

  @doc """
  Decrement the semaphore with the given name.

  This returns immediately with the state updated. The referenced process will be called with
  the reply function once the semaphore is available.

  Processes which acquire the semaphore are monitored, and exits with an acquired process may
  trigger a mailbox `DOWN` message by the caller which must be handled. See the documentation
  for `Process.monitor/1` for more information about the `DOWN` message.

  ## Example

      iex> State.add_pending_process(state, {self(), 0})
      {:ok, %State{}}

      iex> State.add_pending_process(state, {self(), 0})
      {:error, :already_pending_or_active}

  """
  def add_pending_process(%__MODULE__{} = state, {pid, _} = from) do
    if active?(state, pid) or pending?(state, pid) do
      {:error, :already_pending_or_active, state}
    else
      state = update_in(state.pending_processes, &Map.put(&1, pid, from))
      {:ok, try_acquire_process(state)}
    end
  end

  @doc """
  Increment the semaphore with the given name.

  This returns immediately with the state updated, releases the hold given by the specified
  process, and potentially allows another process to begin running.

  ## Example

      iex> State.release_active_process(state, self())
      {:ok, %State{}}

  """
  def release_active_process(%__MODULE__{} = state, pid) do
    if active?(state, pid) do
      {:ok, release_process(state, pid)}
    else
      {:ok, state}
    end
  end

  defp try_acquire_process(%__MODULE__{} = state)
       when state.pending_processes != %{} and
              map_size(state.active_processes) < state.max_concurrency do
    # Start monitoring the process. We will automatically clean up when it exits.
    {pid, from} = Enum.at(state.pending_processes, 0)
    ref = state.monitor.(pid)

    # Drop from pending and add to active.
    state = update_in(state.pending_processes, &Map.delete(&1, pid))
    state = update_in(state.active_processes, &Map.put(&1, pid, ref))

    # Reply to the client which has now acquired the semaphore.
    state.reply.(from, :ok)

    state
  end

  defp try_acquire_process(state) do
    # No pending processes or too many active processes, so nothing to do.
    state
  end

  defp release_process(%__MODULE__{} = state, pid) do
    # Stop watching the process.
    ref = Map.fetch!(state.active_processes, pid)
    state.demonitor.(ref)

    # Drop from active set.
    state = update_in(state.active_processes, &Map.delete(&1, pid))

    # Try to acquire something new.
    try_acquire_process(state)
  end

  defp active?(%__MODULE__{} = state, pid) do
    Map.has_key?(state.active_processes, pid)
  end

  defp pending?(%__MODULE__{} = state, pid) do
    Map.has_key?(state.pending_processes, pid)
  end
end
