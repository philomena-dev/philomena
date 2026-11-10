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

  describe "multiple_pages?/1" do
    test "is true only for a listing longer than a page" do
      assert AppView.multiple_pages?(%Scrivener.Page{total_pages: 2})
      refute AppView.multiple_pages?(%Scrivener.Page{total_pages: 1})
      refute AppView.multiple_pages?(%Scrivener.Page{total_pages: 0})
    end

    test "is false for a listing that failed to load" do
      refute AppView.multiple_pages?(nil)
    end
  end
end
