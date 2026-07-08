defmodule PhilomenaWeb.TagChange.FullRevertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md). full_revert only enqueues a
  # (dead) TagChangeRevertWorker, so there is nothing to observe beyond the
  # flash and redirect.

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

    test "a request with no target key is a case clause error", %{conn: conn} do
      # NOTE: create/2 dispatches on user_id/ip/fingerprint with no fallback,
      # so a request missing all three raises CaseClauseError (500).
      conn = log_in_user(conn, moderator_user_fixture())

      assert_raise CaseClauseError, fn ->
        post(conn, ~p"/tag_changes/full_revert", %{"something" => "else"})
      end
    end
  end
end
