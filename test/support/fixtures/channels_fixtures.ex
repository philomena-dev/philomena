defmodule Philomena.ChannelsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `Philomena.Channels` context.
  """

  alias Philomena.Channels

  def unique_name, do: "channel#{System.unique_integer()}"

  def channel_fixture(attrs \\ %{}) do
    name = unique_name()

    {:ok, channel} =
      attrs
      |> Enum.into(%{
        short_name: name,
        type: "PicartoChannel"
      })
      |> Channels.create_channel()

    channel
  end
end
