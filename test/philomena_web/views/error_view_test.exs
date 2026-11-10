defmodule PhilomenaWeb.ErrorViewTest do
  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.ErrorView

  defp render_page(conn, status) do
    conn = Phoenix.Controller.put_format(conn, "html")
    Phoenix.View.render_to_string(ErrorView, "#{status}.html", conn: conn, status: status)
  end

  test "HTML error pages explain the status in the default theme", %{conn: conn} do
    response = render_page(conn, 404)

    assert response =~ "<title>404 - Philomena</title>"
    assert response =~ "Couldn&#39;t find what you were looking for!"
    assert response =~ ~s(<link href="/css/application.css" rel="stylesheet">)
  end

  test "statuses without their own message read as an internal error", %{conn: conn} do
    response = render_page(conn, 502)

    assert response =~ "Internal Error"
  end

  test "JSON errors carry the short message", %{conn: conn} do
    conn = Phoenix.Controller.put_format(conn, "json")

    assert Phoenix.View.render(ErrorView, "403.json", conn: conn, status: 403) == %{
             "error" => "Forbidden"
           }
  end
end
