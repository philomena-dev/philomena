defmodule PhilomenaWeb.DeactivationController do
  use PhilomenaWeb, :controller

  def show(conn, _params) do
    render(conn, "index.html", title: "Deactivate Account")
  end
end
