defmodule Philomena.RulesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Rules` context.
  """

  @doc """
  Generate a rule.
  """
  def rule_fixture(attrs \\ %{}) do
    {:ok, rule} =
      attrs
      |> Enum.into(%{
        description: "some description",
        example: "some example",
        highlight: true,
        name: "some name",
        position: 42,
        short_description: "some short_description"
      })
      |> Philomena.Rules.create_rule()

    rule
  end
end
