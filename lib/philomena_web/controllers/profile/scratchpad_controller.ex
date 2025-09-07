defmodule PhilomenaWeb.Profile.ScratchpadController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.ModNotes.ModNote

  plug PhilomenaWeb.FilterBannedUsersPlug

  plug :verify_authorized

  plug :load_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    persisted: true

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.user)

    render(conn, "edit.html",
      title: "Editing Moderation Scratchpad",
      changeset: changeset,
      user: conn.assigns.user
    )
  end

  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.user

    case Users.update_scratchpad(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Moderation scratchpad successfully updated.")
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, ModNote) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
