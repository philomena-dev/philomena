defmodule PhilomenaWeb.Admin.User.UnlockControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests (see CHARACTERIZATION-TESTS.md). Postgres-only.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:index, User)`, so ANY moderator (not just admin) can
  # unlock a user.

  describe "POST /admin/users/:user_id/unlock authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = locked_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/unlock")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = locked_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/unlock")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/unlock" do
    setup [:register_and_log_in_admin]

    test "unlocks a locked user and redirects to their profile", %{conn: conn} do
      target = locked_user_fixture()
      assert Repo.get(User, target.id).locked_at != nil

      conn = post(conn, ~p"/admin/users/#{target.slug}/unlock")

      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "unlocked"

      reloaded = Repo.get(User, target.id)
      assert reloaded.locked_at == nil
      assert reloaded.failed_attempts == 0
    end

    # NOTE: succeeds even for an already-unlocked user (the changeset just sets
    # locked_at: nil, failed_attempts: 0 unconditionally).
    test "still succeeds for an already-unlocked user", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/unlock")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).locked_at == nil
    end

    # NOTE: :create is not covered by the not_found handler, so an unknown slug
    # passes nil through and Users.unlock_user(nil) raises FunctionClauseError.
    test "raises for an unknown slug", %{conn: conn} do
      assert_raise FunctionClauseError, fn ->
        post(conn, ~p"/admin/users/no-such-user/unlock")
      end
    end
  end

  describe "POST /admin/users/:user_id/unlock as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is allowed for a plain moderator", %{conn: conn} do
      target = locked_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/unlock")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Repo.get(User, target.id).locked_at == nil
    end
  end
end
