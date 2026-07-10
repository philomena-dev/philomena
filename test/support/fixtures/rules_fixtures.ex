defmodule Philomena.RulesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Rules` context.
  """

  alias Philomena.Rules

  @doc """
  Creates a rule (with its initial system-attributed version).

  Positions are unique because rules derive `Phoenix.Param` from
  `:position`, so duplicate positions would make routes ambiguous.
  """
  def rule_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        name: "Test Rule ##{unique}",
        position: unique
      })

    {:ok, [rule, _version]} = Rules.create_rule_with_version(attrs, nil)

    rule
  end
end
