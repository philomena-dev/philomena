defmodule Philomena.GalleriesFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `Philomena.Galleries` context.
  """

  alias Philomena.Galleries
  alias Philomena.{ImagesFixtures, UsersFixtures}

  def gallery_fixture(attrs \\ %{}) do
    user = UsersFixtures.user_fixture()
    image = ImagesFixtures.image_fixture()

    attrs =
      Enum.into(attrs, %{
        title: "Gallery Fixture",
        thumbnail_id: image.id,
        spoiler_warning: "Spoiler warning",
        description: "Description",
        order_position_asc: false
      })

    {:ok, gallery} = Galleries.create_gallery(user, attrs)

    gallery
  end
end
