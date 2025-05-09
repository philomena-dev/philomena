defmodule PhilomenaWeb.Image.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  plug :load_and_authorize_resource,
    model: TagChange,
    preload: [:user, tags: [:tag]],
    persisted: true,
    only: [:delete]

  def index(conn, params) do
    image = conn.assigns.image

    render(conn, "index.html",
      title: "Tag Changes on Image #{image.id}",
      image: image,
      tag_changes:
        Repo.paginate(
          Images.load_tag_changes(image, params),
          conn.assigns.scrivener
        )
    )
  end

  def delete(conn, _params) do
    image = conn.assigns.image
    tag_change = conn.assigns.tag_change

    TagChanges.delete_tag_change(tag_change)

    conn
    |> put_flash(:info, "Successfully deleted tag change from history.")
    |> moderation_log(
      details: &log_details/2,
      data: %{image: image, details: tag_change_details(tag_change)}
    )
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(_action, %{image: image, details: details}) do
    %{
      body: "Deleted tag change batch #{details} on image #{image.id} from history",
      subject_path: ~p"/images/#{image}"
    }
  end

  defp tag_change_details(%{user: %{name: name}, tags: tags}),
    do: "by #{name} containing #{Enum.count(tags)} change(s)"
end
