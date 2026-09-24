defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias Philomena.Interactions
  import PhilomenaWeb.Api.Json.NotFound

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ApiRequireAuthorizationPlug when action in [:create]

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "image", params_key: "image"] when action in [:create]

  def show(conn, %{"id" => id}) do
    case Images.show_api_image(conn.assigns.actor, id) do
      {:ok, image} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, [image])

        render(conn, "show.json", image: image, interactions: interactions)

      {:error, _not_visible_or_missing} ->
        not_found(conn)
    end
  end

  def create(conn, %{"image" => image_params}) do
    upload = PhilomenaMedia.Upload.cast(image_params, "image")

    case Images.create_image(conn.assigns.actor, image_params, upload) do
      {:ok, %{image: image}} ->
        render(conn, "show.json", image: image, interactions: [])

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", changeset: changeset)
    end
  end
end
