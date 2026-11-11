defmodule PhilomenaWeb.Image.SourceController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias PhilomenaWeb.RefusalResponse

  action_fallback PhilomenaWeb.FallbackController

  plug PhilomenaWeb.CaptchaPlug
  plug PhilomenaWeb.CheckCaptchaPlug

  def update(conn, %{"image" => image_params} = params) do
    case Images.update_image_sources(conn.assigns.actor, params["image_id"], image_params) do
      {:ok, %{image: image, source_change_count: count}} ->
        changeset = Images.change_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: count,
          image: image,
          changeset: changeset
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> render("_source.html",
          layout: false,
          source_change_count: 0,
          image: changeset.data,
          changeset: changeset
        )

      {:error, :rate_limited} ->
        RefusalResponse.call(conn, "You may only update metadata once every 5 seconds.")

      {:error, _} = error ->
        error
    end
  end
end
