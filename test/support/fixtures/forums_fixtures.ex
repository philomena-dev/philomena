defmodule Philomena.ForumsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `Philomena.Forums` context.
  """

  alias Philomena.Forums

  def unique_name do
    for _ <- 1..32, into: <<>>, do: <<Enum.random(?a..?z)>>
  end

  def forum_fixture(attrs \\ %{}) do
    {:ok, forum} =
      attrs
      |> Enum.into(%{
        name: unique_name(),
        short_name: unique_name(),
        description: unique_name(),
        access_level: "normal"
      })
      |> Forums.create_forum()

    forum
  end
end
