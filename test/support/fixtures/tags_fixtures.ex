defmodule Philomena.TagsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Tags` context.
  """

  alias Philomena.Repo
  alias Philomena.Tags

  def unique_tag_name, do: "test tag #{System.unique_integer([:positive])}"

  @doc """
  Creates a tag.

  `Tags.create_tag/1` only accepts `:name` (slug, namespace, and namespace
  category are derived from it — e.g. `"artist:foo"` gets the `origin`
  category automatically). A non-namespace `category:` attr is applied with
  a direct update afterwards, the way the tag controller would.
  """
  def tag_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: unique_tag_name()})
    {category, attrs} = Map.pop(attrs, :category)

    {:ok, tag} = Tags.create_tag(attrs)

    case category do
      nil ->
        tag

      category ->
        tag
        |> Ecto.Changeset.change(category: category)
        |> Repo.update!()
    end
  end
end
