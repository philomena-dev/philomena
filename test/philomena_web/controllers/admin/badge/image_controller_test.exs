defmodule PhilomenaWeb.Admin.Badge.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BadgesFixtures

  alias Philomena.Badges.Badge
  alias Philomena.Repo

  describe "GET /admin/badges/:badge_id/image/edit" do
    test "redirects anonymous users to login", %{conn: conn} do
      badge = badge_fixture()
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for a Badge-role moderator", %{conn: conn} do
      badge = badge_fixture()
      conn = log_in_role_moderator(conn, "Badge")
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      assert html_response(conn, 200) =~ "Upload SVG image"
    end

    test "renders the form for an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/image/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Badge - Derpibooru"
      assert response =~ "Edit Badge"
    end

    test "redirects with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{2_000_000_000}/image/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "crashes on a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/admin/badges/not-a-number/image/edit")
      end
    end
  end

  describe "PATCH /admin/badges/:badge_id/image (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == "/"
    end

    test "updates the badge image as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == ~p"/admin/badges"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Badge updated successfully."
      # NOTE: The image column is rewritten to the pipeline-generated key, so
      # the "test.svg" the fixture inserted is replaced.
      refute Repo.get(Badge, badge.id).image == "test.svg"
    end

    test "updates the badge image as a Badge-role moderator", %{conn: conn} do
      badge = badge_fixture()
      conn = log_in_role_moderator(conn, "Badge")

      conn =
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})

      assert redirected_to(conn) == ~p"/admin/badges"
    end

    # NOTE: `update_badge_image/2` returns `{:error, %Ecto.Changeset{}}`, but
    # the controller matches `{:error, :badge, changeset, _changes}`, so an
    # invalid upload (here, no image) raises CaseClauseError (500) instead of
    # re-rendering the edit form. Same dead error branch as the parent
    # BadgeController.
    test "500s on a validation failure (missing image)", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      assert_raise CaseClauseError, fn ->
        patch(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{}})
      end
    end
  end

  describe "PUT /admin/badges/:badge_id/image (update)" do
    test "updates the badge image as an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = put(conn, ~p"/admin/badges/#{badge}/image", %{"badge" => %{"image" => svg_upload()}})
      assert redirected_to(conn) == ~p"/admin/badges"
    end
  end
end
