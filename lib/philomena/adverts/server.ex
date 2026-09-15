defmodule Philomena.Adverts.Server do
  @moduledoc """
  Batches advert click and impression updates and submits them to the database
  every 10 seconds.
  """

  use GenServer
  alias Philomena.Adverts

  @timeout 0
  @flush_interval to_timeout(second: 10)

  @doc """
  Starts the GenServer.

  See `GenServer.start_link/2` for more information.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Asynchronously records a new impression.

  ## Example

      iex> record_impression(advert.id)
      :ok

  """
  @spec record_impression(integer()) :: :ok
  def record_impression(advert_id) do
    GenServer.cast(__MODULE__, {:impressions, advert_id})
  end

  @doc """
  Asynchronously records a new click.

  ## Example

      iex> record_click(advert.id)
      :ok

  """
  @spec record_click(integer()) :: :ok
  def record_click(advert_id) do
    GenServer.cast(__MODULE__, {:clicks, advert_id})
  end

  @impl true
  @doc false
  def init(_) do
    {:ok, initial_state(), @timeout}
  end

  @impl true
  @doc false
  def handle_cast({type, advert_id}, state) do
    # Update the counter described by the message
    state = update_in(state[type], &increment_counter(&1, advert_id))

    # Return to GenServer event loop
    {:noreply, state, @timeout}
  end

  @impl true
  @doc false
  def handle_info(:timeout, state) do
    # Process all updates from state now
    Adverts.record_counters(state)

    # Return to GenServer event loop and wait for the next flush interval.
    {:noreply, initial_state(), @flush_interval}
  end

  defp increment_counter(map, advert_id) do
    Map.update(map, advert_id, 1, &(&1 + 1))
  end

  defp initial_state do
    %{impressions: %{}, clicks: %{}}
  end
end
