defmodule Philomena.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Channels.AutomaticUpdater
  alias Philomena.Channels.Channel
  alias Philomena.Notifications
  alias Philomena.Tags

  use Philomena.Subscriptions,
    on_delete: :clear_channel_notification,
    id_name: :channel_id

  @doc """
  Updates all the tracked channels for which an update scheme is known.
  """
  def update_tracked_channels! do
    AutomaticUpdater.update_tracked_channels!()
  end

  @doc """
  Gets a single channel.

  Raises `Ecto.NoResultsError` if the Channel does not exist.

  ## Examples

      iex> get_channel!(123)
      %Channel{}

      iex> get_channel!(456)
      ** (Ecto.NoResultsError)

  """
  def get_channel!(id), do: Repo.get!(Channel, id)

  @doc """
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> update_artist_tag(attrs)
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> update_artist_tag(attrs)
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Adds the artist tag from the `"artist_tag"` tag name attribute.

  ## Examples

      iex> update_artist_tag(%Channel{}, %{"artist_tag" => "artist:nighty"})
      %Ecto.Changeset{}

  """
  def update_artist_tag(%Channel{} = channel, attrs) do
    tag =
      attrs
      |> Map.get("artist_tag", "")
      |> Tags.get_tag_by_name()

    Channel.artist_tag_changeset(channel, tag)
  end

  @doc """
  Updates a channel's state when it goes live.

  ## Examples

      iex> update_channel_state(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel_state(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel_state(%Channel{} = channel, attrs) do
    channel
    |> Channel.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.

  ## Examples

      iex> change_channel(channel)
      %Ecto.Changeset{source: %Channel{}}

  """
  def change_channel(%Channel{} = channel) do
    Channel.changeset(channel, %{})
  end

  @doc """
  Removes all channel notifications for a given channel and user.

  ## Examples

      iex> clear_channel_notification(channel, user)
      :ok

  """
  def clear_channel_notification(%Channel{} = channel, user) do
    Notifications.clear_channel_live_notification(channel, user)
    :ok
  end
end
