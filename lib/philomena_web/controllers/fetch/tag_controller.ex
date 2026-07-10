defmodule PhilomenaWeb.Fetch.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias PhilomenaWeb.IntegerId
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"ids" => ids}) when is_list(ids) do
    ids =
      ids
      # limit amount to 50
      |> Enum.take(50)
      |> Enum.flat_map(&parse_id/1)

    tags =
      Tag
      |> where([t], t.id in ^ids)
      |> Repo.all()
      |> Enum.map(&tag_json/1)

    conn
    |> json(%{tags: tags})
  end

  def index(conn, _params), do: json(conn, %{tags: []})

  defp parse_id(id) do
    case IntegerId.parse(id) do
      {:ok, id} -> [id]
      :error -> []
    end
  end

  defp tag_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      images: tag.images_count,
      spoiler_image_uri: tag_image(tag)
    }
  end

  defp tag_image(%{image: image}) when image not in [nil, ""],
    do: tag_url_root() <> "/" <> image

  defp tag_image(_other),
    do: nil

  defp tag_url_root do
    Application.get_env(:philomena, :tag_url_root)
  end
end
