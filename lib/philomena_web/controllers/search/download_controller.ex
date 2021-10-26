defmodule PhilomenaWeb.Search.DownloadController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Elasticsearch
  alias Philomena.Images.Image
  import Ecto.Query

  def index(conn, params) do
    options = [pagination: %{page_number: 1, page_size: 50}]
    queryable = Image |> preload([:user, :intensity, tags: :aliases])

    case ImageLoader.search_string(conn, params["q"], options) do
      {:ok, {images, _tags}} ->
        images = Elasticsearch.search_records(images, queryable)

        conn
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("index.json",
          images: images,
          total: images.total_entries,
          interactions: []
        )

      {:error, msg} ->
        conn
        |> Plug.Conn.put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
