defmodule PhilomenaWeb.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange

  plug :load_and_authorize_resource,
    model: TagChange,
    only: [:delete],
    preload: [:user, :image, tags: [:tag]]

  def index(conn, params) do
    tag_changes =
      TagChanges.load(
        conn.assigns.current_user,
        params,
        conn.assigns.pagination
      )

    render(conn, "index.html",
      title: "Tag Changes",
      tag_changes: tag_changes,
      resource_type: params["resource_type"],
      resource_id: params["resource_id"]
    )
  end

  def delete(conn, params) do
    case TagChanges.delete_tag_change(conn.assigns.tag_change) do
      {:ok, tag_change} ->
        conn
        |> put_flash(:info, "Successfully deleted tag change from history.")
        |> moderation_log(
          details: &log_details/2,
          data: tag_change
        )
        |> redirect(to: params["redirect"])

      _ ->
        conn
        |> put_flash(:error, "Failed to delete tag change from history.")
        |> redirect(to: params["redirect"])
    end
  end

  defp log_details(_action, %{user: %{name: name}, image: image, tags: tags}) do
    %{
      body:
        "Deleted tag change by #{name} containing #{length(tags)} tags on image #{image.id} from history",
      subject_path: ~p"/images/#{image}"
    }
  end
end
