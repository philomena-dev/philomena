defmodule PhilomenaWeb.Api.Json.Search.ReverseController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.DuplicateReports
  alias Philomena.Interactions

  plug PhilomenaWeb.ScraperCachePlug
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

  def create(conn, %{"image" => image_params}) do
    user = conn.assigns.current_user
    image_params = Map.put(image_params, "limit", conn.params["limit"])

    {images, total} =
      conn
      |> ImageLoader.reverse_filter()
      |> DuplicateReports.execute_search_query_by_features(image_params)
      |> case do
        {:ok, images} ->
          {images, images.total_entries}

        {:error, _changeset} ->
          {[], 0}
      end

    interactions = Interactions.user_interactions(images, user)

    conn
    |> put_view(PhilomenaWeb.Api.Json.ImageView)
    |> render("index.json",
      images: images,
      total: total,
      interactions: interactions
    )
  end
end
