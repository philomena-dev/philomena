defmodule PhilomenaWeb.Web3SignerController do
  use PhilomenaWeb, :controller
  alias Philomena.Users.User
  plug :load_and_authorize_resource,
    model: User,
    only: :show,
    id_field: "slug",
    preload: []

  def index(conn, params) do

    user = conn.assigns.current_user

    data = %{

      name: user.name,
      id: user.id,

      desc: "Hello Crypto Brony, welcome to Derpibooru! We need your signture to confirm your web3 identity into your account.\n\nUsername: {name}\nId: {id}"

    }

    render conn, data: data

  end
end
