defmodule PhilomenaWeb.FingerprintProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserFingerprintsFixtures

  describe "GET /fingerprint_profiles/:id" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/fingerprint_profiles/#{"abc123"}")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/fingerprint_profiles/#{"abc123"}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the profile and lists users seen on the fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()
      user_fingerprint_fixture(user, "abc123")

      response = html_response(get(conn, ~p"/fingerprint_profiles/#{"abc123"}"), 200)

      assert response =~ "abc123&#39;s fingerprint profile"
      assert response =~ user.name
    end

    # NOTE: unlike the IP profile, the fingerprint is used directly as a string
    # (no `EctoNetwork.INET.cast`), so any value — including one with no
    # activity — renders a 200 rather than crashing.
    test "renders an empty profile for a fingerprint with no activity", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/fingerprint_profiles/#{"no-such-fp"}"), 200)

      assert response =~ "no-such-fp&#39;s fingerprint profile"
    end
  end
end
