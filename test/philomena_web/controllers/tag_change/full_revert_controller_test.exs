defmodule PhilomenaWeb.TagChange.FullRevertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # full_revert only enqueues a (dead) TagChangeRevertWorker, so there is
  # nothing to observe beyond the flash and redirect.

  import Philomena.UsersFixtures

  describe "POST /tag_changes/full_revert" do
    test "is rejected for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = post(conn, ~p"/tag_changes/full_revert", %{"user_id" => "#{user.id}"})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      user = confirmed_user_fixture()
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = post(conn, ~p"/tag_changes/full_revert", %{"user_id" => "#{user.id}"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator enqueues a reversion for a user", %{conn: conn} do
      target = confirmed_user_fixture()
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tag_changes/full_revert", %{"user_id" => "#{target.id}"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a moderator enqueues a reversion for an ip", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tag_changes/full_revert", %{"ip" => "203.0.113.5"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a moderator enqueues a reversion for a fingerprint", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tag_changes/full_revert", %{"fingerprint" => "c1774e9294a"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Reversion of tag changes enqueued"
    end

    test "a request with no target key redirects with the failure flash", %{conn: conn} do
      # NOTE: a request naming none of user_id/ip/fingerprint now redirects to
      # the referrer with the failure flash rather than raising CaseClauseError.
      conn = log_in_user(conn, moderator_user_fixture())

      conn = post(conn, ~p"/tag_changes/full_revert", %{"something" => "else"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Couldn't revert those tag changes!"
    end
  end
end
