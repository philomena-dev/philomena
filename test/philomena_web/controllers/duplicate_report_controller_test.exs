defmodule PhilomenaWeb.DuplicateReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The :index/:show/:create actions live in the public (Tor-authorized)
  # scope with no Canary gate, so any visitor can reach them; the
  # accept/reject/claim moderation children are tested separately.

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.DuplicateReportsFixtures

  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Repo

  describe "GET /duplicate_reports" do
    test "lists open/claimed reports for anonymous users", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = get(conn, ~p"/duplicate_reports")
      response = html_response(conn, 200)

      assert response =~ "Duplicate Reports - Derpibooru"
      assert response =~ ~p"/images/#{source}"
      assert response =~ ~p"/images/#{target}"
      _ = dr
    end

    test "renders with no reports", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports")

      assert html_response(conn, 200) =~ "Duplicate Reports - Derpibooru"
    end

    test "the default view omits rejected/accepted reports", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      dr
      |> Ecto.Changeset.change(state: "rejected")
      |> Repo.update!()

      conn = get(conn, ~p"/duplicate_reports")
      response = html_response(conn, 200)

      # NOTE: index defaults to the "open"/"claimed" states, so a rejected
      # report is hidden unless ?states[] asks for it explicitly.
      refute response =~ ~p"/images/#{source}"

      conn = get(conn, ~p"/duplicate_reports?#{[states: ["rejected"]]}")
      assert html_response(conn, 200) =~ ~p"/images/#{source}"
    end

    test "an unrecognized state param falls back to nothing matching", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      duplicate_report_fixture(source, target)

      # NOTE: index filters the requested states against a fixed allowlist; a
      # bogus state leaves an empty list, so no reports render at all.
      conn = get(conn, ~p"/duplicate_reports?#{[states: ["bogus"]]}")
      response = html_response(conn, 200)

      assert response =~ "Duplicate Reports - Derpibooru"
      refute response =~ ~p"/images/#{source}"
    end
  end

  describe "GET /duplicate_reports/:id" do
    test "shows a report to anonymous users", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()
      dr = duplicate_report_fixture(source, target)

      conn = get(conn, ~p"/duplicate_reports/#{dr}")
      response = html_response(conn, 200)

      # NOTE: the show page renders an SVG diff of the two images (not plain
      # /images/N links), so pin the title and the source/target caption.
      assert response =~ "Showing Duplicate Report - Derpibooru"
      assert response =~ "Left is source, right is target"
      _ = {source, target}
    end

    test "an unknown id redirects with the not-found flash", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports/#{123_456_789}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer id redirects with the not-found flash", %{conn: conn} do
      conn = get(conn, ~p"/duplicate_reports/not-an-integer")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "POST /duplicate_reports" do
    test "an anonymous visitor can create a report", %{conn: conn} do
      source = image_fixture()
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => target.id,
            "reason" => "same image"
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "created successfully"

      dr = Repo.get_by!(DuplicateReport, image_id: source.id, duplicate_of_image_id: target.id)
      assert dr.state == "open"
      assert dr.user_id == nil
    end

    test "a logged-in user is recorded as the reporter", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = log_in_user(conn, user)
      source = image_fixture()
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => target.id
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"

      dr = Repo.get_by!(DuplicateReport, image_id: source.id)
      assert dr.user_id == user.id
    end

    test "reporting an image as a duplicate of itself fails validation", %{conn: conn} do
      source = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => source.id
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to submit duplicate report"
      refute Repo.exists?(DuplicateReport)
    end

    # NOTE: create now loads images with a parse-guarded Repo.get; an unknown (or
    # non-integer) source image_id has nowhere to redirect back to, so it takes
    # the NotFoundPlug path rather than raising.
    test "an unknown source image id redirects with the not-found flash", %{conn: conn} do
      target = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => 123_456_789,
            "duplicate_of_image_id" => target.id
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    # NOTE: a valid source with an unknown duplicate_of_image_id redirects back
    # to the source image with the submission-failure flash.
    test "an unknown target image id redirects to the source with the failure flash",
         %{conn: conn} do
      source = image_fixture()

      conn =
        post(conn, ~p"/duplicate_reports", %{
          "duplicate_report" => %{
            "image_id" => source.id,
            "duplicate_of_image_id" => 123_456_789
          }
        })

      assert redirected_to(conn) == ~p"/images/#{source}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to submit duplicate report"
      refute Repo.exists?(DuplicateReport)
    end

    # NOTE: a request without the duplicate_report param takes the fallback
    # create/2 clause and answers via NotFoundPlug.
    test "a missing duplicate_report param redirects with the not-found flash", %{conn: conn} do
      conn = post(conn, ~p"/duplicate_reports", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
