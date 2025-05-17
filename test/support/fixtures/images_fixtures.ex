defmodule Philomena.ImagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Images` context.
  """

  alias Philomena.Images
  alias Philomena.Users.User

  @default_image_attrs %{
    "image" => %Plug.Upload{
      path: "#{__DIR__}/upload-test.png",
      filename: "upload-test.png",
      content_type: "image/png"
    },
    "tag_input" => "safe,tag1,tag2",
    "sources" => ["https://localhost/images_fixtures.ex"]
  }

  @spec image_fixture(User.t(), map()) :: Images.Image.t()
  def image_fixture(uploader, attrs \\ %{}) do
    principal = [
      user: uploader
    ]

    attrs = Map.merge(@default_image_attrs, attrs)

    {:ok, %{image: image}} = Images.create_image(principal, attrs)

    image
  end
end
