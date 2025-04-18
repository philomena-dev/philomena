defmodule PhilomenaWeb.Api.Json.Search.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias PhilomenaQuery.Cursor
  alias Philomena.Interactions
  alias Philomena.Images.Image
  import Ecto.Query

  def index(conn, params) do
    queryable = Image |> preload([:user, :intensity, :sources, tags: :aliases])
    user = conn.assigns.current_user

    case ImageLoader.search_string(conn, params["q"]) do
      {:ok, {images, _tags}} ->
        {images, cursors} = Cursor.search_records(images, queryable, params["search_after"])
        interactions = Interactions.user_interactions(images, user)

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("index.json",
          images: images,
          cursors: cursors,
          total: images.total_entries,
          interactions: interactions
        )

      {:error, msg} ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
