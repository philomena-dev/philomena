defmodule PhilomenaWeb.Registration.Web3Controller do
  use PhilomenaWeb, :controller

  alias Philomena.Web3
  alias PhilomenaWeb.Web3Cfg

  def edit(conn, params) do
    tinyWeb3Cfg = Web3Cfg.get()
    if tinyWeb3Cfg.enable_profile do
      changeset = Web3.change_address(conn.assigns.current_user)
      render(conn, "edit.html", title: "Editing Web3 Account", changeset: changeset, current_user: conn.assigns.current_user)
    else
      conn
      |> put_flash(:warn, "This page has been disabled by the website owner.")
      |> redirect(to: "/registrations/edit")
    end
  end

  def update(conn, %{"user" => user_params}) do
    tinyWeb3Cfg = Web3Cfg.get()
    if tinyWeb3Cfg.enable_profile do
      case Web3.update_address(conn.assigns.current_user, user_params) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "Web3 Address successfully updated.")
          |> redirect(to: Routes.profile_path(conn, :show, user))

        {:error, changeset} ->
          render(conn, "edit.html", changeset: changeset)
      end
    else
      conn
      |> put_flash(:warn, "This page has been disabled by the website owner.")
      |> redirect(to: "/registrations/edit")
    end
  end

end
