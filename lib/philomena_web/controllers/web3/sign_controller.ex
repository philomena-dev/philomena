defmodule PhilomenaWeb.Web3SignerController do
  use PhilomenaWeb, :controller
  alias PhilomenaWeb.Web3SignerData
  def index(conn, params) do
    data = Web3SignerData.get(conn.assigns.current_user)
    render conn, data: data
  end
end
