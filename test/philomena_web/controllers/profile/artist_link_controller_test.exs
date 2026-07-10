defmodule PhilomenaWeb.Profile.ArtistLinkControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.ArtistLinks
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Repo

  defp artist_tag_fixture do
    tag_fixture(name: "artist:test-link-artist-#{System.unique_integer([:positive])}")
  end

  defp artist_link_fixture(user) do
    {:ok, link} =
      ArtistLinks.create_artist_link(user, %{
        "tag_name" => artist_tag_fixture().name,
        "uri" => "https://example.com/gallery-#{System.unique_integer([:positive])}"
      })

    link
  end

  describe "GET /profiles/:profile_id/artist_links" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/artist_links")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "lists the user's own links on their own profile", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      link = artist_link_fixture(user)

      response = html_response(get(conn, ~p"/profiles/#{user}/artist_links"), 200)

      assert response =~ "Artist Links - Derpibooru"
      assert response =~ link.uri
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/artist_links")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "shows a moderator their own links on another user's profile", %{conn: conn} do
      # NOTE: index queries by current_user, not the profile being viewed -
      # a moderator opening an artist's link page sees their own (usually
      # empty) list, not the artist's links.
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)

      response = html_response(get(conn, ~p"/profiles/#{artist}/artist_links"), 200)

      refute response =~ link.uri
    end
  end

  describe "GET /profiles/:profile_id/artist_links/new" do
    test "renders the form on the user's own profile", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/profiles/#{user}/artist_links/new"), 200)

      assert response =~ "New Artist Link - Derpibooru"
      assert response =~ "Request Artist Link"
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{user}/artist_links/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "POST /profiles/:profile_id/artist_links" do
    test "creates an unverified link and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = artist_tag_fixture()

      conn =
        post(conn, ~p"/profiles/#{user}/artist_links", %{
          "artist_link" => %{
            "tag_name" => tag.name,
            "uri" => "https://example.com/my-gallery"
          }
        })

      link = Repo.get_by!(ArtistLink, user_id: user.id)
      assert link.aasm_state == "unverified"
      assert link.tag_id == tag.id
      assert redirected_to(conn) == ~p"/profiles/#{user}/artist_links/#{link}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Link submitted! Please put '#{link.verification_code}' on your linked webpage now."
    end

    test "with a non-creator tag re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture()

      conn =
        post(conn, ~p"/profiles/#{user}/artist_links", %{
          "artist_link" => %{"tag_name" => tag.name, "uri" => "https://example.com/x"}
        })

      # NOTE: failure re-renders new.html without the :title assign
      assert html_response(conn, 200) =~ "Request Artist Link"
      refute Repo.get_by(ArtistLink, user_id: user.id)
    end

    test "with a non-http uri re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = artist_tag_fixture()

      conn =
        post(conn, ~p"/profiles/#{user}/artist_links", %{
          "artist_link" => %{"tag_name" => tag.name, "uri" => "ftp://example.com/x"}
        })

      assert html_response(conn, 200) =~ "Request Artist Link"
      refute Repo.get_by(ArtistLink, user_id: user.id)
    end
  end

  describe "GET /profiles/:profile_id/artist_links/:id" do
    test "renders the user's own link", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      link = artist_link_fixture(user)

      response =
        html_response(get(conn, ~p"/profiles/#{user}/artist_links/#{link}"), 200)

      assert response =~ "Showing Artist Link - Derpibooru"
      assert response =~ link.uri
    end

    test "renders another user's link for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)

      assert html_response(get(conn, ~p"/profiles/#{artist}/artist_links/#{link}"), 200) =~
               link.uri
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)

      conn = get(conn, ~p"/profiles/#{artist}/artist_links/#{link}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "GET /profiles/:profile_id/artist_links/:id/edit" do
    test "redirects the link's owner with the authorization flash", %{conn: conn} do
      # NOTE: no ability rule grants users :edit on their own ArtistLink -
      # editing is moderator-only even under the owner's profile.
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      link = artist_link_fixture(user)

      conn = get(conn, ~p"/profiles/#{user}/artist_links/#{link}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)

      assert html_response(
               get(conn, ~p"/profiles/#{artist}/artist_links/#{link}/edit"),
               200
             ) =~ "Editing Artist Link - Derpibooru"
    end
  end

  describe "PATCH /profiles/:profile_id/artist_links/:id" do
    test "updates the link as a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)
      tag = artist_tag_fixture()

      conn =
        patch(conn, ~p"/profiles/#{artist}/artist_links/#{link}", %{
          "artist_link" => %{
            "tag_name" => tag.name,
            "uri" => "https://example.com/updated",
            "public" => "true"
          }
        })

      assert redirected_to(conn) == ~p"/profiles/#{artist}/artist_links/#{link}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Link successfully updated."

      reloaded = Repo.get!(ArtistLink, link.id)
      assert reloaded.uri == "https://example.com/updated"
      assert reloaded.tag_id == tag.id
    end

    test "redirects the link's owner with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      link = artist_link_fixture(user)

      conn =
        patch(conn, ~p"/profiles/#{user}/artist_links/#{link}", %{
          "artist_link" => %{"uri" => "https://example.com/updated"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(ArtistLink, link.id).uri == link.uri
    end
  end

  describe "DELETE /profiles/:profile_id/artist_links/:id" do
    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      link = artist_link_fixture(user)

      conn = delete(conn, ~p"/profiles/#{user}/artist_links/#{link}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(ArtistLink, link.id)
    end

    test "crashes for an admin because the action does not exist", %{conn: conn} do
      # NOTE: the router generates DELETE via `resources "/artist_links"`,
      # but the controller defines no delete/2 - a dead route reachable only
      # by admins (who pass every authorization check). KNOWN-ODDITIES.md.
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      artist = confirmed_user_fixture()
      link = artist_link_fixture(artist)

      assert_raise UndefinedFunctionError, ~r/delete\/2/, fn ->
        delete(conn, ~p"/profiles/#{artist}/artist_links/#{link}")
      end
    end
  end
end
