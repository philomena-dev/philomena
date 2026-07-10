defmodule PhilomenaWeb.Page.HistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.StaticPagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.StaticPages

  describe "GET /pages/:page_id/history" do
    test "renders the revision history for anonymous users", %{conn: conn} do
      editor = user_fixture()
      page = static_page_fixture(editor, %{body: "old line"})

      {:ok, _} =
        StaticPages.update_static_page(page, editor, %{
          title: page.title,
          slug: page.slug,
          body: "new line"
        })

      conn = get(conn, ~p"/pages/#{page}/history")
      response = html_response(conn, 200)

      assert response =~ "Revision History for Page"
      assert response =~ page.title
      assert response =~ editor.name
      assert response =~ "old line"
      assert response =~ "new line"
    end

    test "renders the initial version for a never-edited page", %{conn: conn} do
      page = static_page_fixture(user_fixture())

      conn = get(conn, ~p"/pages/#{page}/history")
      response = html_response(conn, 200)

      assert response =~ "Revision History for Page"
      assert response =~ page.title
    end

    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      # NOTE: load_resource now uses required: true, so Canary runs its
      # not-found handler on this :index action - an unknown slug redirects
      # instead of dereferencing a nil page.
      conn = get(conn, ~p"/pages/nonexistent-page/history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
