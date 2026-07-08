defmodule PhilomenaWeb.Admin.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # The index action reads the Report OpenSearch index, so this module is
  # search-backed.

  @moduletag :search

  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures

  alias Philomena.Reports.Report
  alias PhilomenaQuery.SearchHelpers

  setup do
    SearchHelpers.recreate_index!(Report)
    :ok
  end

  defp open_report_fixture do
    image = image_fixture()
    report_fixture({"Image", image.id})
  end

  describe "GET /admin/reports authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert html_response(conn, 200) =~ "Reports"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/reports")
      assert html_response(conn, 200) =~ "Reports"
    end
  end

  describe "GET /admin/reports (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports")
      response = html_response(conn, 200)
      assert response =~ "Admin - Reports - Derpibooru"
      assert response =~ "We couldn't find any reports for you, sorry!"
    end

    test "lists an open report in the default view", %{conn: conn} do
      report = open_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports")
      response = html_response(conn, 200)
      assert response =~ report.reason
    end

    test "supports the rq search branch", %{conn: conn} do
      report = open_report_fixture()
      SearchHelpers.reindex_all!(Report)

      conn = get(conn, ~p"/admin/reports?#{[rq: "open:true"]}")
      response = html_response(conn, 200)
      assert response =~ report.reason
    end
  end

  describe "GET /admin/reports/:id (show) authorization" do
    setup do
      %{report: open_report_fixture()}
    end

    test "redirects anonymous users to login", %{conn: conn, report: report} do
      conn = get(conn, ~p"/admin/reports/#{report}")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/reports/#{report}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn, report: report} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/reports/#{report}")
      response = html_response(conn, 200)
      assert response =~ "Showing Report"
      assert response =~ report.reason
    end
  end

  describe "GET /admin/reports/:id (show) failure paths" do
    setup [:register_and_log_in_admin]

    # NOTE: :show runs Canary's not-found handler for an unknown id.
    test "redirects for an unknown report id", %{conn: conn} do
      conn = get(conn, ~p"/admin/reports/#{0}")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    # NOTE: a non-integer report id raises Ecto.Query.CastError (a 500).
    test "raises on a non-integer report id", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/admin/reports/not-an-integer")
      end
    end
  end
end
