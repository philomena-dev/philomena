defmodule Philomena.ChannelsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Channels` context.
  """

  alias Philomena.Channels

  def unique_channel_short_name, do: "test_channel_#{System.unique_integer([:positive])}"

  @doc """
  Creates a channel.

  Attrs are string-keyed the way the admin channel controller submits them;
  pass `"artist_tag" => tag.name` to associate an existing artist tag.
  """
  def channel_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "type" => "PicartoChannel",
        "short_name" => unique_channel_short_name()
      })

    {:ok, channel} = Channels.create_channel(attrs)

    channel
  end
end
