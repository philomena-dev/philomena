defmodule PhilomenaWeb.Registration.Web3Controller do
  use PhilomenaWeb, :controller

  alias Philomena.Web3
  plug PhilomenaWeb.FilterBannedUsersPlug

  def edit(conn, params) do
    changeset = Web3.change_address(conn.assigns.current_user)
    render(conn, "edit.html", title: "Editing Web3 Account", changeset: changeset, current_user: conn.assigns.current_user)
  end

  def update(conn, %{"user" => user_params}) do
    case Web3.update_address(conn.assigns.current_user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Web3 Address successfully updated.")
        |> redirect(to: Routes.registration_web3_path(conn, :show, user))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

end
