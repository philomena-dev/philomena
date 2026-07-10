defmodule PhilomenaWeb.IpProfile.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures
  import Philomena.SourceChangesFixtures

  describe "GET /ip_profiles/:ip_profile_id/source_changes" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "lists source changes attributed to the IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()
      source_change_fixture(image, ip: "203.0.113.1", source_url: "https://pinned.example/art")

      response = html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.1"}/source_changes"), 200)

      assert response =~ "Source changes by"
      assert response =~ "https://pinned.example/art"
    end

    test "renders an empty listing for an IP with no source changes", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      response =
        html_response(get(conn, ~p"/ip_profiles/#{"203.0.113.99"}/source_changes"), 200)

      assert response =~ "Source changes by"
    end

    # NOTE: same `{:ok, ip} = EctoNetwork.INET.cast(ip)` match as the IP profile
    # - an unparsable IP raises `MatchError` (a 500).
    test "500s on an unparsable IP", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise MatchError, ~r/no match of right hand side value:\s*:error/, fn ->
        get(conn, ~p"/ip_profiles/#{"not-an-ip"}/source_changes")
      end
    end
  end
end
