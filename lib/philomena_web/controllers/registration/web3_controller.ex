defmodule PhilomenaWeb.Registration.Web3Controller do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug :verify_authorized

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.current_user)

    render(conn, "edit.html", title: "Editing Web3 Account", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do

  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :change_username, conn.assigns.current_user) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
