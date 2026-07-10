defmodule Philomena.ForumsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Forums` context.
  """

  alias Philomena.Forums

  @doc """
  Generates a unique forum short name.

  Short names may only contain lowercase letters, so the unique integer is
  spelled out in base-26 letters.
  """
  def unique_forum_short_name do
    suffix =
      System.unique_integer([:positive])
      |> Integer.digits(26)
      |> Enum.map(&(&1 + ?a))
      |> List.to_string()

    "testforum" <> suffix
  end

  def forum_fixture(attrs \\ %{}) do
    {:ok, forum} =
      attrs
      |> Enum.into(%{
        name: "Test Forum",
        short_name: unique_forum_short_name(),
        description: "A forum for testing",
        access_level: "normal"
      })
      |> Forums.create_forum()

    forum
  end
end
