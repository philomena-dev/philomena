defmodule PhilomenaJob.Listener.State do
  @moduledoc """
  Internal listener state.
  """

  defmodule Entry do
    @moduledoc false

    defstruct channel_name: nil,
              pid: nil,
              process_ref: nil,
              listen_ref: nil
  end

  defstruct entries: [],
            notify: nil,
            unlisten: nil,
            listen: nil,
            demonitor: nil,
            monitor: nil

  @doc """
  Create a new instance of the internal listener state.

  Supported options:
  - `:notify`: callback which receives a worker pid. Required.
  - `:unlisten`: callback to stop listening to a channel. Required.
  - `:listen`: callback to begin listening to a channel. Required.
  - `:demonitor`: callback to de-monitor a process. Optional, defaults to `Process.demonitor/1`.
  - `:monitor`: callback to monitor a process. Optional, defaults to `Process.monitor/1`.

  ## Examples

      iex> State.new(listen: &Notifier.listen!/2, unlisten: &Notifier.unlisten!/2)
      %State{}

  """
  def new(opts) do
    notify = Keyword.fetch!(opts, :notify)
    unlisten = Keyword.fetch!(opts, :unlisten)
    listen = Keyword.fetch!(opts, :listen)
    demonitor = Keyword.get(opts, :demonitor, &Process.demonitor/1)
    monitor = Keyword.get(opts, :monitor, &Process.monitor/1)

    %__MODULE__{
      notify: notify,
      unlisten: unlisten,
      listen: listen,
      demonitor: demonitor,
      monitor: monitor
    }
  end

  @doc """
  Registers the given `worker_pid` to activate when `channel_name` receives a notification.

  Processes which are added are monitored, and exits with any added process may trigger a
  mailbox `DOWN` message by the caller which must be handled. See the documentation
  for `Process.monitor/1` for more information about the `DOWN` message.

  ## Example

      iex> add_worker(state, "image_index_requests", self())
      %State{}

  """
  def add_worker(%__MODULE__{} = state, channel_name, worker_pid) do
    # Ensure that there is no worker already registered with this pid.
    [] = filter_by(state, pid: worker_pid)

    # Monitor and begin listening.
    process_ref = state.monitor.(worker_pid)
    listen_ref = state.listen.(channel_name)

    # Add to state.
    e = %Entry{
      channel_name: channel_name,
      pid: worker_pid,
      process_ref: process_ref,
      listen_ref: listen_ref
    }

    update_in(state.workers, &([e] ++ &1))
  end

  @doc """
  Unregisters the given `worker_pid` for notifications.

  ## Example

      iex> remove_worker(state, self())
      %State{}

  """
  def remove_worker(%__MODULE__{} = state, worker_pid) do
    case filter_by(state, pid: worker_pid) do
      [%Entry{} = entry] ->
        # Stop listening and unmonitor.
        state.unlisten.(entry.listen_ref)
        state.demonitor.(entry.process_ref)

        # Remove from state.
        erase_by(state, pid: worker_pid)

      [] ->
        state
    end
  end

  @doc """
  Sends a worker listening on the given `listen_ref` a notification using the
  `notify` callback.

  ## Example

      iex> notify_workers(state, listen_ref)
      %State{}

  """
  def notify_worker(%__MODULE__{} = state, listen_ref) do
    for entry <- filter_by(state, listen_ref: listen_ref) do
      state.notify.(entry.pid)
    end

    state
  end

  defp filter_by(%__MODULE__{} = state, [{key, value}]) do
    Enum.filter(state.entries, &match?(%{^key => ^value}, &1))
  end

  defp erase_by(%__MODULE__{} = state, [{key, value}]) do
    workers = Enum.filter(state.entries, &(not match?(%{^key => ^value}, &1)))

    put_in(state.workers, workers)
  end
end
