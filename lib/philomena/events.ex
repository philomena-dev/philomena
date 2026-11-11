defmodule Philomena.Events do
  @event_topic "__internal__:events"

  @doc """
  Broadcasts an internal event to the current node.

  ## Example

      iex> broadcast(%ImageUpdate{image: %Image{}})
      :ok

  """
  @spec broadcast(Phoenix.PubSub.message()) :: :ok
  def broadcast(event) do
    Phoenix.PubSub.local_broadcast(Philomena.PubSub, @event_topic, event)
  end

  @doc """
  Registers the current process to receive internal events. Events are typed
  and belong to the following list:

  - `%Events.CommentCreate{}`
  - `%Events.CommentUpdate{}`
  - `%Events.ImageBatchUpdate{}`
  - `%Events.ImageCreate{}`
  - `%Events.ImageDescriptionUpdate{}`
  - `%Events.ImageMerge{}`
  - `%Events.ImageProcess{}`
  - `%Events.ImageSourceUpdate{}`
  - `%Events.ImageTagUpdate{}`
  - `%Events.ImageUpdate{}`
  - `%Events.PostCreate{}`

  Events are sent via normal IPC messages; you can retrieve them in a `receive`
  block, or through a GenServer's `handle_info` callback.

  ## Examples

      iex> subscribe_events()
      :ok

  """
  @spec subscribe_events() :: :ok
  def subscribe_events do
    Phoenix.PubSub.subscribe(Philomena.PubSub, @event_topic)
  end

  @doc """
  Unsubscribes the current process from receiving future internal events.

  ## Example

    iex> unsubscribe_events()
    :ok

  """
  @spec unsubscribe_events() :: :ok
  def unsubscribe_events do
    Phoenix.PubSub.unsubscribe(Philomena.PubSub, @event_topic)
  end
end
