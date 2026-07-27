defmodule PhilomenaWeb.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  action_fallback PhilomenaWeb.FallbackController

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
    case TagChanges.delete_tag_change(conn.assigns.current_user, params["id"]) do
      {:ok, _tag_change} ->
        conn
        |> put_flash(:info, "Successfully deleted tag change from history.")
        |> redirect(to: params["redirect"])

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to delete tag change from history.")
        |> redirect(to: params["redirect"])

      {:error, _} = error ->
        error
    end
  end
end
