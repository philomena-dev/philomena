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

    test "crashes for an unknown slug", %{conn: conn} do
      # NOTE: probable bug (KNOWN-ODDITIES.md). Canary's load_resource does
      # not run the not-found handler for :index actions, so an unknown
      # slug reaches the controller with a nil page and crashes (500)
      # instead of 404ing.
      assert_raise BadMapError, ~r/expected a map/, fn ->
        get(conn, ~p"/pages/nonexistent-page/history")
      end
    end
  end
end
