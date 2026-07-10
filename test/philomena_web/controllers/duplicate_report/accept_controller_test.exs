defmodule PhilomenaWeb.DuplicateReport.AcceptControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Accepting a report merges the source image into the target: the merge
  # runs synchronously (S3 ops go through the ex_aws stub, reindexing is a
  # dead Exq enqueue).

  import Philomena.ImagesFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Repo

  describe "POST /duplicate_reports/:duplicate_report_id/accept" do
    test "is rejected for anonymous users", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, Philomena.UsersFixtures.confirmed_user_fixture())
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator accepts the report and merges the source image", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = post(conn, ~p"/duplicate_reports/#{dr}/accept")

      assert redirected_to(conn) == ~p"/duplicate_reports"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully accepted report"

      dr = Repo.get!(DuplicateReport, dr.id)
      assert dr.state == "accepted"

      # merge_image hides the source image and points it at the target
      source = Repo.get!(Philomena.Images.Image, source.id)
      assert source.hidden_from_users == true
      assert source.duplicate_id == target.id
    end

    test "an unknown report id takes the not-authorized redirect", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      # NOTE: load_and_authorize_resource authorizes a nil resource for a
      # moderator (no rule matches), so an unknown id redirects rather than 404s.
      conn = post(conn, ~p"/duplicate_reports/#{123_456_789}/accept")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a non-integer report id raises a cast error", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/duplicate_reports/not-an-integer/accept")
      end
    end
  end
end
