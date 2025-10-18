defmodule PhilomenaWeb.OpensearchController do
  use PhilomenaWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/xml")
    |> put_format(:xml)
    |> render("index.xml")
  end
end
