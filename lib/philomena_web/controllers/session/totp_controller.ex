defmodule PhilomenaWeb.Session.TotpController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.LayoutView
  alias PhilomenaWeb.UserAuth
  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo

  def new(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)

    render(conn, "new.html", layout: {LayoutView, "two_factor.html"}, changeset: changeset)
  end

  def create(conn, %{"user" => user_params} = params) when is_map(user_params) do
    conn.assigns.current_user
    |> User.consume_totp_token_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _changeset} ->
        invalid_token(conn)

      {:ok, user} ->
        UserAuth.totp_auth_user(conn, user, user_params)
    end
  end

  def create(conn, _params), do: invalid_token(conn)

  defp invalid_token(conn) do
    conn
    |> put_flash(:error, "Invalid TOTP token entered. Please sign in again.")
    |> UserAuth.log_out_user()
  end
end
