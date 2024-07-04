defmodule Philomena.ImagesFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the `Philomena.Images` context.
  """

  alias Philomena.Images
  alias Philomena.{AttributionFixtures, UsersFixtures}

  def image_fixture(opts \\ []) do
    user = Keyword.get_lazy(opts, :user, fn -> UsersFixtures.user_fixture() end)

    attribution =
      Keyword.get_lazy(opts, :attribution, fn -> AttributionFixtures.attribution_fixture(user) end)

    {:ok, %{image: image}} = Images.create_image(attribution, upload_attrs())

    image
  end

  def upload_attrs do
    path = Plug.Upload.random_file!("test-image")
    File.write!(path, random_png())

    %{
      "tag_input" => "safe, qr code, test fixture",
      "image" => %Plug.Upload{
        filename: "test-image",
        content_type: "application/octet-stream",
        path: path
      },
      "anonymous" => false
    }
  end

  defp random_png do
    128
    |> :crypto.strong_rand_bytes()
    |> QRCode.to_png()
  end
end
