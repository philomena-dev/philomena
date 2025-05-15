defmodule Philomena.TagsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the
  `Philomena.Tags` context.
  """

  alias Philomena.Tags.Tag
  alias Philomena.Repo

  def tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      %Tag{id: attrs.id}
      |> Tag.creation_changeset(attrs)
      |> Repo.insert()

    tag
  end
end
