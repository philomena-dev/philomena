defmodule PhilomenaWeb.AppViewTest do
  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.AppView

  describe "get_flash/2" do
    test "reads a message the controller flashed", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> fetch_flash()
        |> put_flash(:error, "Something went wrong")

      assert AppView.get_flash(conn, :error) == "Something went wrong"
      assert AppView.get_flash(conn, :info) == nil
    end

    test "has no message on a connection without a flash", %{conn: conn} do
      assert AppView.get_flash(conn, :error) == nil
    end
  end
end
