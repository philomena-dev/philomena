defmodule PhilomenaWeb.EthereumProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do

    # Get Ethereum Address
    id = conn.params["id"]

    # No Ethereum Address
    if is_nil(id) do
      conn
      |> redirect(to: "/")

    # Yes
    else
      user =
        User
        |> where(ethereum: ^id)
        |> preload([:slug])
        |> Repo.one()

      conn
      |> redirect(to: "/profiles/" <> user.slug)
    end

  end
end
