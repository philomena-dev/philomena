defmodule PhilomenaWeb.ReactivationController do
  use PhilomenaWeb, :controller

  def index(conn, _params) do
    text(conn, "hello world")
  end
end
