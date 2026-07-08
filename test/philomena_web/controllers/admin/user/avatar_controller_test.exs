defmodule PhilomenaWeb.Admin.User.AvatarControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md). Postgres-only: the S3 delete in
  # Users.remove_avatar/1 goes through the stubbed ex_aws client and the
  # reindex is a dead Exq enqueue; moderation_log/2 is a synchronous insert.

  import Philomena.UsersFixtures

  alias Philomena.Users.User
  alias Philomena.Repo

  # NOTE: gated on `can?(:index, User)`, so ANY moderator (not just admin) can
  # remove another user's avatar.

  describe "DELETE /admin/users/:user_id/avatar authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      target = user_with_avatar_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      target = user_with_avatar_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "DELETE /admin/users/:user_id/avatar" do
    setup [:register_and_log_in_admin]

    test "removes the avatar and redirects to the admin edit page", %{conn: conn} do
      target = user_with_avatar_fixture()
      assert Repo.get(User, target.id).avatar == "test/avatar.png"

      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")

      assert redirected_to(conn) == ~p"/admin/users/#{target}/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "removed avatar"
      assert Repo.get(User, target.id).avatar == nil
    end

    # NOTE: succeeds even when the user has no avatar — remove_avatar_changeset
    # just sets avatar: nil unconditionally.
    test "still succeeds when the user has no avatar", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == ~p"/admin/users/#{target}/edit"
      assert Repo.get(User, target.id).avatar == nil
    end

    # NOTE: :delete runs Canary's not_found handler, so an unknown slug
    # redirects to "/" with the not-found flash instead of crashing.
    test "redirects for an unknown slug", %{conn: conn} do
      conn = delete(conn, ~p"/admin/users/no-such-user/avatar")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /admin/users/:user_id/avatar as a plain moderator" do
    setup [:register_and_log_in_moderator]

    test "is allowed for a plain moderator", %{conn: conn} do
      target = user_with_avatar_fixture()
      conn = delete(conn, ~p"/admin/users/#{target.slug}/avatar")
      assert redirected_to(conn) == ~p"/admin/users/#{target}/edit"
      assert Repo.get(User, target.id).avatar == nil
    end
  end
end
