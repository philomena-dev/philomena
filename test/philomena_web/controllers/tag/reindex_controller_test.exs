defmodule PhilomenaWeb.Tag.ReindexControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # :create is gated on :alias (a plain moderator lacks it) and only
  # enqueues (dead) reindex workers, so there is nothing to observe beyond
  # the flash and redirect. Tags are slug-keyed, so there is no
  # non-integer-id crash.

  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  describe "POST /tags/:tag_id/reindex" do
    test "is a login redirect for anonymous users", %{conn: conn} do
      tag = tag_fixture()
      conn = post(conn, ~p"/tags/#{tag}/reindex")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = post(conn, ~p"/tags/#{tag}/reindex")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "is rejected for a plain moderator", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tags/#{tag}/reindex")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "an admin starts a reindex", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_user(conn, admin_user_fixture())
      conn = post(conn, ~p"/tags/#{tag}/reindex")

      assert redirected_to(conn) == ~p"/tags/#{tag}/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag reindex started"
    end

    test "a Tag-admin role_map moderator can start a reindex", %{conn: conn} do
      tag = tag_fixture()
      conn = log_in_role_moderator(conn, "Tag")
      conn = post(conn, ~p"/tags/#{tag}/reindex")

      assert redirected_to(conn) == ~p"/tags/#{tag}/edit"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Tag reindex started"
    end

    test "an unknown slug is the not-authorized redirect for a role_map moderator", %{
      conn: conn
    } do
      # NOTE: a role-mod fails authorization on the nil resource (no rule
      # matches nil), so Canary's unauthorized handler fires — "can't access".
      # An admin passes authorization and instead hits the not-found handler
      # (see the next test), so the same unknown slug yields a different flash
      # depending on role.
      conn = log_in_role_moderator(conn, "Tag")
      conn = post(conn, ~p"/tags/nonexistent-tag/reindex")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "an unknown slug is the not-found redirect for an admin", %{conn: conn} do
      # NOTE: can?(admin, _, nil) is true, so an admin sails past the nil
      # authorization — but load_and_authorize_resource has persisted: true, so
      # Canary's not_found_handler fires on the nil resource before create/2
      # runs. The admin gets a clean "Couldn't find" redirect, NOT a 500.
      conn = log_in_user(conn, admin_user_fixture())
      conn = post(conn, ~p"/tags/nonexistent-tag/reindex")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
