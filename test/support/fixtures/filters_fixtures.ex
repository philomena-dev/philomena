defmodule Philomena.FiltersFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the
  `Philomena.Filters` context.
  """

  alias Philomena.Filters.Filter
  alias Philomena.Repo

  def system_filter_fixture(attrs \\ %{}) do
    {:ok, filter} =
      %Filter{id: attrs.id, system: true}
      |> Filter.changeset(attrs)
      |> Repo.insert()

    filter
  end
end
