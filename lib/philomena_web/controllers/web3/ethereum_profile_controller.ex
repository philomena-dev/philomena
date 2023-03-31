defmodule PhilomenaWeb.EthereumProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"id" => id}) do

    user =
      User
      |> where(ethereum: ^id)
      |> preload([:slug])
      |> Repo.one()

    conn
    |> redirect(to: "/profiles/" <> user.slug)

  end
end
