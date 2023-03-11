defmodule PhilomenaWeb.Registration.Web3Controller do
  use PhilomenaWeb, :controller

  alias Philomena.Search.Parser
  alias Philomena.Users
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug

  def edit(conn, params) do
    changeset = Users.change_user(conn.assigns.current_user)
    render(conn, "edit.html", title: "Editing Web3 Account", changeset: changeset, current_user: conn.assigns.current_user)
  end

  def update(conn, %{"user" => user_params}) do

  end

end
