defmodule PhilomenaWeb.Admin.ArtistLinkControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ArtistLinksFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  describe "GET /admin/artist_links authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/artist_links")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/artist_links")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "allows a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/artist_links")
      assert html_response(conn, 200) =~ "Artist Links"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/artist_links")
      assert html_response(conn, 200) =~ "Artist Links"
    end
  end

  describe "GET /admin/artist_links (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/artist_links")
      response = html_response(conn, 200)
      assert response =~ "Admin - Artist Links - Derpibooru"
      assert response =~ "Artist Links"
    end

    test "lists an unverified link by default", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:index-unverified")
      link = artist_link_fixture(user, tag)

      conn = get(conn, ~p"/admin/artist_links")
      response = html_response(conn, 200)
      assert response =~ link.uri
      assert response =~ user.name
    end

    # NOTE: the default index only lists links in the unverified/link_verified/
    # contacted states — a verified link is hidden unless ?all is passed.
    test "hides a verified link by default but shows it with ?all", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:index-verified")
      link = verified_artist_link_fixture(user, tag)

      conn = get(conn, ~p"/admin/artist_links")
      refute html_response(conn, 200) =~ link.uri

      conn = get(conn, ~p"/admin/artist_links?#{[all: "true"]}")
      assert html_response(conn, 200) =~ link.uri
    end

    test "filters by user name or uri with lq", %{conn: conn} do
      user = confirmed_user_fixture()
      tag = tag_fixture(name: "artist:index-lq")
      link = artist_link_fixture(user, tag)

      other = confirmed_user_fixture()
      other_tag = tag_fixture(name: "artist:index-lq-other")
      other_link = artist_link_fixture(other, other_tag)

      conn = get(conn, ~p"/admin/artist_links?#{[lq: user.name]}")
      response = html_response(conn, 200)
      assert response =~ link.uri
      refute response =~ other_link.uri
    end
  end
end
