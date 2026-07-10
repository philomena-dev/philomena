defmodule PhilomenaWeb.Admin.User.WipeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Postgres-only. The actual PII wipe is performed by UserWipeWorker, which
  # is only enqueued (a dead Exq enqueue in test), so only the flash/redirect
  # and the synchronous moderation_log insert are observable here.

  import Philomena.UsersFixtures

  # NOTE: gated on `can?(:index, User)`, so ANY moderator (not just admin) can
  # queue a PII wipe.

  describe "POST /admin/users/:user_id/wipe authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = confirmed_user_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "POST /admin/users/:user_id/wipe" do
    setup [:register_and_log_in_admin]

    test "queues the wipe and redirects to their profile", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "PII wipe queued"
    end

    # NOTE: :create is not covered by the not_found handler, so an unknown slug
    # passes nil through; the controller dereferences user.id (BadMapError on
    # nil) before the worker enqueue - nil-pass-through family.
    test "raises for an unknown slug", %{conn: conn} do
      assert_raise BadMapError, ~r/expected a map, got:\s*nil/, fn ->
        post(conn, ~p"/admin/users/no-such-user/wipe")
      end
    end
  end

  describe "POST /admin/users/:user_id/wipe as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is allowed for a plain moderator", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = post(conn, ~p"/admin/users/#{target.slug}/wipe")
      assert redirected_to(conn) == ~p"/profiles/#{target}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "PII wipe queued"
    end
  end
end
