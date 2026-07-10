defmodule PhilomenaWeb.TagChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  # The read-only :index action and the moderation :delete action are both
  # covered here.

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Repo
  alias Philomena.TagChanges.TagChange
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  import Ecto.Query

  setup do
    Search.clear_index!(TagChange)
    # Valkey rate-limit counters are not rolled back by the SQL sandbox; reset
    # the tag-change limit so accumulated counts don't trip check_limits.
    reset_tag_change_limits()
    :ok
  end

  defp tag_change_fixture!(user, added_tags \\ "added test tag, other added tag") do
    image = image_fixture()

    # The tag changeset requires at least 3 tags, so the update keeps the
    # fixture's "safe" tag and adds two more.
    {:ok, _} =
      Images.update_tags(image, attribution(user), %{
        "old_tag_input" => "safe",
        "tag_input" => "safe, #{added_tags}"
      })

    SearchHelpers.reindex_all!(TagChange)
    image
  end

  # Returns the single TagChange row created for `image`. The moderation-log
  # detail formatter pattern-matches `%{user: %{name: name}}`, so the change
  # must be authored by a real user (an anonymous change would crash the log).
  defp tag_change_row!(image) do
    Repo.one!(from tc in TagChange, where: tc.image_id == ^image.id)
  end

  describe "GET /tag_changes" do
    test "lists tag changes for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)

      conn = get(conn, ~p"/tag_changes")
      response = html_response(conn, 200)

      assert response =~ "Tag Changes - Derpibooru"
      assert response =~ "added test tag"
      assert response =~ ~p"/images/#{image}"
      assert response =~ user.name
    end

    test "renders with no tag changes", %{conn: conn} do
      conn = get(conn, ~p"/tag_changes")

      assert html_response(conn, 200) =~ "Tag Changes - Derpibooru"
    end

    test "filters by tcq query", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)

      conn = get(conn, ~p"/tag_changes?#{[tcq: "image_id:#{image.id}"]}")
      response = html_response(conn, 200)

      assert response =~ "added test tag"

      conn = get(conn, ~p"/tag_changes?#{[tcq: "image_id:#{image.id + 1}"]}")
      response = html_response(conn, 200)

      refute response =~ "added test tag"
    end

    test "resource_type=image filters the listing to that image's changes", %{conn: conn} do
      image = tag_change_fixture!(confirmed_user_fixture(), "filtered marker tag, second tag")

      _other_image =
        tag_change_fixture!(confirmed_user_fixture(), "unrelated marker tag, second tag")

      conn = get(conn, ~p"/tag_changes?#{[resource_type: "image", resource_id: image.id]}")
      response = html_response(conn, 200)

      # The heading names the resource, as before...
      assert response =~ "Showing tag changes for"
      assert response =~ "image ##{image.id}"

      # ...and the resource params now also filter the listing: only the
      # requested image's change appears, the unrelated one is absent.
      assert response =~ "filtered marker tag"
      refute response =~ "unrelated marker tag"
    end

    test "resource_type=user filters by user name, case-insensitively", %{conn: conn} do
      user = confirmed_user_fixture()
      tag_change_fixture!(user, "filtered marker tag, second tag")
      tag_change_fixture!(confirmed_user_fixture(), "unrelated marker tag, second tag")

      # The filter downcases the given name before the term match.
      conn =
        get(
          conn,
          ~p"/tag_changes?#{[resource_type: "user", resource_id: String.upcase(user.name)]}"
        )

      response = html_response(conn, 200)

      assert response =~ "filtered marker tag"
      refute response =~ "unrelated marker tag"
    end

    test "tcq composes with resource params as AND", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      other_image = image_fixture()

      # tcq matching + resource filter pointing at the same image: listed.
      conn1 =
        get(
          conn,
          ~p"/tag_changes?#{[tcq: "image_id:#{image.id}", resource_type: "image", resource_id: image.id]}"
        )

      assert html_response(conn1, 200) =~ "added test tag"

      # The same tcq ANDed with a resource filter for a change-free image
      # matches nothing.
      conn2 =
        get(
          conn,
          ~p"/tag_changes?#{[tcq: "image_id:#{image.id}", resource_type: "image", resource_id: other_image.id]}"
        )

      refute html_response(conn2, 200) =~ "added test tag"
    end

    test "resource_type=ip lists nothing for non-staff viewers", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      # attribution/1 stamps every change with 203.0.113.1, but ip filtering
      # is moderator/admin-only - anonymous viewers get match_none.
      conn = get(conn, ~p"/tag_changes?#{[resource_type: "ip", resource_id: "203.0.113.1"]}")

      refute html_response(conn, 200) =~ "added test tag"
    end

    test "a moderator can filter by ip; an invalid ip matches nothing", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      conn = log_in_user(conn, moderator_user_fixture())

      conn1 = get(conn, ~p"/tag_changes?#{[resource_type: "ip", resource_id: "203.0.113.1"]}")
      assert html_response(conn1, 200) =~ "added test tag"

      conn2 = get(conn, ~p"/tag_changes?#{[resource_type: "ip", resource_id: "not-an-ip"]}")
      refute html_response(conn2, 200) =~ "added test tag"
    end

    test "an unknown resource_type lists nothing", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      conn = get(conn, ~p"/tag_changes?#{[resource_type: "banana", resource_id: "1"]}")

      refute html_response(conn, 200) =~ "added test tag"
    end
  end

  describe "DELETE /tag_changes/:id" do
    test "is rejected for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)

      # NOTE: /tag_changes sits in the Tor-authorized scope, not the
      # login-required one, so an anonymous visitor is stopped by the Canary
      # authorization (redirect to "/") rather than a login redirect.
      conn = delete(conn, ~p"/tag_changes/#{tc}", %{"redirect" => ~p"/images/#{image}"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
      assert Repo.get(TagChange, tc.id)
    end

    test "is rejected for regular users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)

      conn = log_in_user(conn, confirmed_user_fixture())
      conn = delete(conn, ~p"/tag_changes/#{tc}", %{"redirect" => ~p"/images/#{image}"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
      assert Repo.get(TagChange, tc.id)
    end

    test "a moderator deletes the tag change and is redirected to the redirect param", %{
      conn: conn
    } do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)

      conn = log_in_user(conn, moderator_user_fixture())
      conn = delete(conn, ~p"/tag_changes/#{tc}", %{"redirect" => ~p"/images/#{image}"})

      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully deleted tag change"
      refute Repo.get(TagChange, tc.id)
    end

    test "an unknown id takes the not-authorized redirect", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      # NOTE: load_and_authorize_resource authorizes a nil resource for a
      # moderator (no :delete rule matches nil), so an unknown id redirects.
      conn = delete(conn, ~p"/tag_changes/#{123_456_789}", %{"redirect" => "/"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a non-integer id redirects with the not-found flash", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      conn = delete(conn, ~p"/tag_changes/not-an-integer", %{"redirect" => "/"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
