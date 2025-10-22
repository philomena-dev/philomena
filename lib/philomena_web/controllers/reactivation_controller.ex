defmodule PhilomenaWeb.ReactivationController do
  use PhilomenaWeb, :controller
  alias Philomena.Users.{User}
  alias Philomena.Users

  def show(conn, %{"id" => _}) do
    render(conn, "show.html", title: "Reactivate Your Account")
  end

  def create(conn, %{"token" => token}) do
    with user = %User{} <- Users.get_user_by_reactivation_token(token) do
      Users.reactivate_user(user)
    else
      nil ->
        nil
    end

    conn
    |> put_flash(:info, "If the token provided was valid, your account has been reactivated.")
    |> redirect(to: "/")
  end
end
