defmodule PhilomenaWeb.Image.FeatureController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id}) do
    with {:ok, _feature} <- Images.create_image_feature(conn.assigns.actor, image_id) do
      conn
      |> put_flash(:info, "Image marked as featured image.")
      |> redirect(to: ~p"/images/#{image_id}")
    end
  end
end
