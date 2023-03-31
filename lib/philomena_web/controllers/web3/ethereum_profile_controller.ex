defmodule PhilomenaWeb.EthereumProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"id" => id}) do

    user =
      User
      |> where(ethereum: ^id)
      |> Repo.one()

    if user do
      if user.slug do
        conn
        |> redirect(to: "/profiles/" <> user.slug)
      else
        conn
        |> redirect(to: "/")
      end
    else
      conn
      |> redirect(to: "/")
    end

  end
end
