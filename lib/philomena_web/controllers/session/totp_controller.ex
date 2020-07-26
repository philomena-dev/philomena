defmodule PhilomenaWeb.Session.TotpController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.LayoutView
  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo

  def new(conn, _params) do
    changeset = Users.change_user(conn)

    render(conn, "new.html", layout: {LayoutView, "two_factor.html"}, changeset: changeset)
  end

  def create(conn, params) do
    conn.assigns.current_user
    |> User.consume_totp_token_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _changeset} ->
        conn
        # |> Pow.Plug.delete()
        |> put_flash(:error, "Invalid TOTP token entered. Please sign in again.")
        |> redirect(to: "/")

      {:ok, user} ->
        conn
        |> PhilomenaWeb.TotpPlug.update_valid_totp_at_for_session(user)
        |> redirect(to: "/")
    end
  end
end
