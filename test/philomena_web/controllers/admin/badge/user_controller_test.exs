defmodule PhilomenaWeb.Admin.Badge.UserControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.BadgesFixtures
  import Philomena.UsersFixtures

  describe "GET /admin/badges/:badge_id/users authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      badge = badge_fixture()
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert redirected_to(conn) == "/"
    end

    test "allows a moderator with the Badge role_map entry", %{conn: conn} do
      badge = badge_fixture()
      conn = log_in_role_moderator(conn, "Badge")
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert html_response(conn, 200) =~ "Users with"
    end

    test "allows an admin", %{conn: conn} do
      badge = badge_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert html_response(conn, 200) =~ "Users with"
    end
  end

  describe "GET /admin/badges/:badge_id/users content" do
    setup [:register_and_log_in_admin]

    test "renders the empty list for a badge with no awards", %{conn: conn} do
      badge = badge_fixture()
      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      response = html_response(conn, 200)
      assert response =~ "Users with badge #{badge.title} - Derpibooru"
      assert response =~ "Users with"
    end

    test "lists users who hold the badge", %{conn: conn} do
      badge = badge_fixture()
      recipient = confirmed_user_fixture()
      _award = badge_award_fixture(admin_user_fixture(), recipient, badge)

      conn = get(conn, ~p"/admin/badges/#{badge}/users")
      assert html_response(conn, 200) =~ recipient.name
    end
  end

  describe "GET /admin/badges/:badge_id/users unknown id" do
    setup [:register_and_log_in_admin]

    # NOTE: For the :index action Canary's load_resource does not run its
    # not_found handler, so an unknown badge_id leaves `@badge` nil and the
    # query builds `^nil.id`, raising BadMapError (the same nil pass-through
    # family as the other :index routes).
    test "500s on an unknown badge_id", %{conn: conn} do
      assert_raise BadMapError, ~r/expected a map, got:\s*nil/, fn ->
        get(conn, ~p"/admin/badges/#{2_000_000_000}/users")
      end
    end

    test "crashes on a non-integer badge_id", %{conn: conn} do
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/admin/badges/not-a-number/users")
      end
    end
  end
end
