defmodule PhilomenaWeb.Api.Json.OembedController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias PhilomenaWeb.IntegerId
  alias Philomena.Repo
  import Ecto.Query

  @cdn_regex ~r/\/img\/.*\/(\d+)(\.|[\/_][_\w])/
  @img_regex ~r/\/(\d+)/

  def index(conn, %{"url" => url}) when is_binary(url) do
    url
    |> URI.parse()
    |> try_oembed(conn)
  end

  def index(conn, _params), do: oembed_error(conn)

  # A URL with no path at all (e.g. `https://example.com`) parses to a nil path.
  defp try_oembed(%{path: path}, conn) when is_binary(path) do
    cdn = Regex.run(@cdn_regex, path, capture: :all_but_first)
    img = Regex.run(@img_regex, path, capture: :all_but_first)

    image_id =
      cond do
        cdn -> hd(cdn)
        img -> hd(img)
        true -> nil
      end

    image_id
    |> load_image()
    |> oembed_image(conn)
  end

  defp try_oembed(_parsed, conn), do: oembed_error(conn)

  defp load_image(nil), do: nil

  defp load_image(id) do
    case IntegerId.parse(id) do
      {:ok, id} ->
        Image
        |> where(id: ^id, hidden_from_users: false)
        |> preload([:user, :sources, tags: :aliases])
        |> Repo.one()

      :error ->
        nil
    end
  end

  defp oembed_image(nil, conn), do: oembed_error(conn)
  defp oembed_image(image, conn), do: render(conn, "show.json", image: image)

  defp oembed_error(conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> render("error.json")
  end
end
