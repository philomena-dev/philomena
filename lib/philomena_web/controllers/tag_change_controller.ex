defmodule PhilomenaWeb.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  plug :load_and_authorize_resource, model: TagChange, except: [:index], preload: :user
  plug PhilomenaWeb.RequireUserPlug when action not in [:index]

  def index(conn, params) do
    tag_changes =
      TagChanges.load(
        conn.assigns.current_user,
        params,
        conn.assigns.scrivener
      )

    render(conn, "index.html",
      title: "Tag Changes",
      tag_changes: tag_changes,
      thing: params["thing"],
      thing_value: params["value"]
    )
  end

  def delete(conn, params) do
    tag_change = conn.assigns.tag_change

    TagChanges.delete_tag_change(tag_change)

    conn
    |> put_flash(:info, "Successfully deleted tag change from history.")
    |> moderation_log(
      details: &log_details/2,
      data: tag_change
    )
    |> redirect(to: ~p"/#{params["redirect"]}")
  end

  defp log_details(_action, %{user: %{name: name}, image: image, tags: tags}) do
    %{
      body:
        "Deleted tag change by #{name} containing #{length(tags)} tags on image #{image.id} from history",
      subject_path: ~p"/images/#{image}"
    }
  end
end
