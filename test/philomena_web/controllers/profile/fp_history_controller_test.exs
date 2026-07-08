defmodule PhilomenaWeb.Profile.FpHistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserFingerprintsFixtures

  describe "GET /profiles/:profile_id/fp_history" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/fp_history")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/fp_history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the history and cross-references other users on the same fingerprint",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()
      alias_user = confirmed_user_fixture()

      user_fingerprint_fixture(subject, "deadbeef")
      user_fingerprint_fixture(alias_user, "deadbeef")

      response = html_response(get(conn, ~p"/profiles/#{subject}/fp_history"), 200)

      assert response =~ "FP History for"
      assert response =~ subject.name
      assert response =~ alias_user.name
    end

    test "renders an empty history when the user has no fingerprint rows", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      subject = confirmed_user_fixture()

      response = html_response(get(conn, ~p"/profiles/#{subject}/fp_history"), 200)

      assert response =~ "FP History for"
      assert response =~ subject.name
    end

    # NOTE: same `load_and_authorize_resource` `:index` shape as ip_history —
    # an unknown slug takes the not-authorized redirect, not the not-found one.
    test "redirects an unknown profile slug with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{"nonexistent-slug"}/fp_history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end
end
