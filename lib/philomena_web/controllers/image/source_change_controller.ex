defmodule PhilomenaWeb.Image.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SpoilerExecutor
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def index(conn, _params) do
    image = conn.assigns.image

    source_changes =
      SourceChange
      |> where(image_id: ^image.id)
      |> preload([:user, image: [:user]])
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.scrivener)

    spoilers =
      SpoilerExecutor.execute_spoiler(
        conn.assigns.compiled_spoiler,
        Enum.map(source_changes, & &1.image)
      )

    render(conn, "index.html",
      title: "Source Changes on Image #{image.id}",
      image: image,
      source_changes: source_changes,
      spoilers: spoilers
    )
  end
end
