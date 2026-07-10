defmodule PhilomenaWeb.IpProfileControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.UserIpsFixtures

  describe "GET /ip_profiles/:id" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the profile and lists users seen on the IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()
      user_ip_fixture(user, "203.0.113.1")

      response = html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.1"}"), 200)

      assert response =~ "203.0.113.1&#39;s IP profile"
      assert response =~ user.name
    end

    test "renders an empty profile for an IP with no activity", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response = html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.250"}"), 200)

      assert response =~ "203.0.113.250&#39;s IP profile"
    end

    # NOTE: the id is cast with `{:ok, ip} = EctoNetwork.INET.cast(ip)`, so a
    # value that doesn't parse as an IP/CIDR raises `MatchError` (a 500) rather
    # than a not-found response - the same shape as the admin subnet-ban pages.
    test "500s on an unparsable IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise MatchError, ~r/no match of right hand side value:\s*:error/, fn ->
        get(conn, ~p"/ip_profiles/#{"not-an-ip"}")
      end
    end
  end
end
