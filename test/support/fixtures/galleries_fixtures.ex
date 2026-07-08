defmodule Philomena.GalleriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Galleries` context.
  """

  alias Philomena.Galleries

  def unique_gallery_title, do: "Test Gallery #{System.unique_integer([:positive])}"

  @doc """
  Creates a gallery owned by `user`.

  A gallery requires a thumbnail image; when `:thumbnail_id` is not given,
  a fresh `Philomena.ImagesFixtures.image_fixture/1` is created for it.
  """
  def gallery_fixture(user, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{title: unique_gallery_title()})
      |> Map.put_new_lazy(:thumbnail_id, fn -> Philomena.ImagesFixtures.image_fixture().id end)

    {:ok, gallery} = Galleries.create_gallery(user, attrs)

    gallery
  end
end
