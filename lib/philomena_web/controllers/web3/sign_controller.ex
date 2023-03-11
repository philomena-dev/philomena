defmodule PhilomenaWeb.Web3SignerController do
  use PhilomenaWeb, :controller

  def index(conn, params) do

    data = %{

      name: conn.assigns.current_user.name,
      id: conn.assigns.current_user.id,

      desc: "Hello Crypto Brony, welcome to Derpibooru! We need your signture to confirm your web3 identity into your account.\n\nUsername: {name}\nId: {id}"

    }

    render conn, data: data

  end
end
