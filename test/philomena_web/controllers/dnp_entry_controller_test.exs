defmodule PhilomenaWeb.DnpEntryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.DnpEntriesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.ArtistLinks
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Repo

  # The DNP form only offers tags from the user's verified artist links
  # (the :set_tags plug rejects users without any)
  defp verify_artist_link!(user, tag) do
    {:ok, link} =
      ArtistLinks.create_artist_link(user, %{
        "tag_name" => tag.name,
        "uri" => "https://example.com/gallery"
      })

    {:ok, _link} = ArtistLinks.verify_artist_link(link, user)
    :ok
  end

  describe "GET /dnp" do
    test "renders listed entries for anonymous users", %{conn: conn} do
      tag = tag_fixture(name: "artist:test-dnp-artist")
      user = confirmed_user_fixture()

      entry =
        dnp_entry_fixture(user, tag, %{
          "conditions" => "Test no edits condition",
          state: "listed"
        })

      conn = get(conn, ~p"/dnp")
      response = html_response(conn, 200)

      assert response =~ "Do-Not-Post List - Derpibooru"
      assert response =~ "The Do-Not-Post (DNP) List"
      assert response =~ "test-dnp-artist"
      assert response =~ "Test no edits condition"
      assert response =~ ~p"/dnp/#{entry}"
    end

    test "does not list unprocessed (requested) entries", %{conn: conn} do
      tag = tag_fixture(name: "artist:test-requested-artist")
      _entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn = get(conn, ~p"/dnp")
      response = html_response(conn, 200)

      refute response =~ "test-requested-artist"
    end

    test "shows the requester their own entries with ?mine=1", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mine-artist")
      _entry = dnp_entry_fixture(user, tag)

      conn = get(conn, ~p"/dnp?mine=1")
      response = html_response(conn, 200)

      assert response =~ "test-mine-artist"
    end
  end

  describe "GET /dnp/:id" do
    test "renders a listed entry for anonymous users", %{conn: conn} do
      tag = tag_fixture(name: "artist:test-shown-artist")

      entry =
        dnp_entry_fixture(confirmed_user_fixture(), tag, %{
          "conditions" => "Test shown conditions",
          "reason" => "Test shown reason",
          state: "listed"
        })

      conn = get(conn, ~p"/dnp/#{entry}")
      response = html_response(conn, 200)

      assert response =~ "Showing DNP Listing - Derpibooru"
      assert response =~ "DNP Listing for Tag"
      assert response =~ "test-shown-artist"
      assert response =~ "Test shown conditions"
    end

    test "redirects to / for a requested entry as anonymous", %{conn: conn} do
      tag = tag_fixture(name: "artist:test-private-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn = get(conn, ~p"/dnp/#{entry}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "renders a requested entry for its requesting user", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-own-artist")
      entry = dnp_entry_fixture(user, tag)

      conn = get(conn, ~p"/dnp/#{entry}")
      response = html_response(conn, 200)

      assert response =~ "DNP Listing for Tag"
      assert response =~ "test-own-artist"
    end

    test "redirects to / for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/dnp/999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end

  describe "GET /dnp/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/dnp/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects users without a verified artist link with the authorization flash",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/dnp/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a user with a verified artist link", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-new-form-artist")
      verify_artist_link!(user, tag)

      response = html_response(get(conn, ~p"/dnp/new"), 200)

      assert response =~ "New DNP Listing - Derpibooru"
      assert response =~ "New DNP Request"
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/dnp/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "POST /dnp" do
    test "creates a requested entry for the linked tag and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-create-artist")
      verify_artist_link!(user, tag)

      conn =
        post(conn, ~p"/dnp", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "No Edits",
            "reason" => "Test created DNP reason",
            "conditions" => ""
          }
        })

      entry = Repo.one!(from d in DnpEntry, where: d.requesting_user_id == ^user.id)

      assert redirected_to(conn) == ~p"/dnp/#{entry}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully submitted DNP request."
      assert entry.aasm_state == "requested"
      assert entry.tag_id == tag.id
      assert entry.reason == "Test created DNP reason"
    end

    test "re-renders the form when the reason is blank", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-invalid-artist")
      verify_artist_link!(user, tag)

      conn =
        post(conn, ~p"/dnp", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "No Edits",
            "reason" => ""
          }
        })

      assert html_response(conn, 200) =~ "New DNP Request"
      refute Repo.exists?(from d in DnpEntry, where: d.requesting_user_id == ^user.id)
    end

    test "crashes when the submitted tag is not one of the user's linked tags", %{conn: conn} do
      # NOTE: create_dnp_entry looks the tag up in the selectable list and
      # passes the nil miss straight into the changeset, which crashes on
      # tag.id - same nil pass-through family as KNOWN-ODDITIES.md
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-owned-artist")
      other_tag = tag_fixture(name: "artist:test-unowned-artist")
      verify_artist_link!(user, tag)

      assert_raise BadMapError, ~r/expected a map, got:\s*nil/, fn ->
        post(conn, ~p"/dnp", %{
          "dnp_entry" => %{
            "tag_id" => to_string(other_tag.id),
            "dnp_type" => "No Edits",
            "reason" => "Not my tag"
          }
        })
      end
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/dnp", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end
  end

  describe "GET /dnp/:id/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/dnp/1/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects the requesting artist with the authorization flash", %{conn: conn} do
      # NOTE: there is no user-facing edit - only moderators can edit entries,
      # even the artist who requested one cannot
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-requester-artist")
      verify_artist_link!(user, tag)
      entry = dnp_entry_fixture(user, tag)

      conn = get(conn, ~p"/dnp/#{entry}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects a moderator without a tag_id param with the authorization flash",
         %{conn: conn} do
      # NOTE: the :set_tags plug offers moderators the ?tag_id= tag, but
      # falls back to their own linked tags without it - a moderator with no
      # verified artist link of their own cannot open the edit form bare
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mod-bare-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn = get(conn, ~p"/dnp/#{entry}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator with a tag_id param", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mod-edit-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn = get(conn, ~p"/dnp/#{entry}/edit?#{[tag_id: tag.id]}")
      response = html_response(conn, 200)

      assert response =~ "Editing DNP Listing - Derpibooru"
      assert response =~ "Edit DNP Request"
    end
  end

  describe "PATCH /dnp/:id" do
    test "updates the entry as a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mod-update-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn =
        patch(conn, ~p"/dnp/#{entry}?#{[tag_id: tag.id]}", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "Other",
            "reason" => "Updated DNP reason",
            "conditions" => "Updated conditions"
          }
        })

      assert redirected_to(conn) == ~p"/dnp/#{entry}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully updated DNP request."

      reloaded = Repo.reload!(entry)
      assert reloaded.reason == "Updated DNP reason"
      assert reloaded.dnp_type == "Other"
    end

    test "PUT also updates the entry", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mod-put-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn =
        put(conn, ~p"/dnp/#{entry}?#{[tag_id: tag.id]}", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "No Edits",
            "reason" => "Updated via PUT"
          }
        })

      assert redirected_to(conn) == ~p"/dnp/#{entry}"
      assert Repo.reload!(entry).reason == "Updated via PUT"
    end

    test "re-renders the form when the reason is blank", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      tag = tag_fixture(name: "artist:test-mod-invalid-artist")
      entry = dnp_entry_fixture(confirmed_user_fixture(), tag)

      conn =
        patch(conn, ~p"/dnp/#{entry}?#{[tag_id: tag.id]}", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "No Edits",
            "reason" => ""
          }
        })

      assert html_response(conn, 200) =~ "Edit DNP Request"
      assert Repo.reload!(entry).reason == entry.reason
    end

    test "redirects the requesting artist with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      tag = tag_fixture(name: "artist:test-requester-update-artist")
      verify_artist_link!(user, tag)
      entry = dnp_entry_fixture(user, tag)

      conn =
        patch(conn, ~p"/dnp/#{entry}?#{[tag_id: tag.id]}", %{
          "dnp_entry" => %{
            "tag_id" => to_string(tag.id),
            "dnp_type" => "No Edits",
            "reason" => "Hijacked"
          }
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(entry).reason == entry.reason
    end
  end
end
