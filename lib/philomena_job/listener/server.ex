defmodule PhilomenaJob.Listener.Server do
  @moduledoc """
  A listener server which holds references to worker processes, and converts database
  event notifications into messages for those worker processes.

  A `PhilomenaJob.NotifierServer` reference must be provided. This is a server pid or name.

  A supervision tree example:

      children = [
        {PhilomenaJob.Listener.Server, name: WorkerListener, notifier: WorkerNotifier}
      ]

  """

  alias PhilomenaJob.Listener.State
  alias PhilomenaJob.NotifierServer
  alias PhilomenaJob.Worker

  use GenServer, restart: :temporary, significant: true

  @doc """
  Registers the current process to activate when `channel_name` receives a notification.

  Process listeners are automatically unregistered when the process exits.

  ## Example

      iex> link_worker(listener_ref, "image_index_requests")
      :ok

  """
  def link_worker(listener, channel_name) do
    :ok = GenServer.call(listener, {:link_worker, channel_name})
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  @impl true
  def init(opts) do
    notifier = Keyword.fetch!(opts, :notifier)

    unlisten = &NotifierServer.unlisten!(notifier, &1)
    listen = &NotifierServer.listen!(notifier, &1)
    notify = &Worker.notify/1

    {:ok, State.new(unlisten: unlisten, listen: listen, notify: notify)}
  end

  @doc false
  @impl true
  def handle_call({:link_worker, channel_name}, {pid, _}, state) do
    {:reply, :ok, State.add_worker(state, channel_name, pid)}
  end

  @doc false
  @impl true
  def handle_info(message, state)

  def handle_info({:DOWN, _ref, :process, worker_pid, _reason}, state) do
    {:noreply, State.remove_worker(state, worker_pid)}
  end

  def handle_info({:notification, _pid, listen_ref, _channel_name, _message}, state) do
    {:noreply, State.notify_worker(state, listen_ref)}
  end
end
