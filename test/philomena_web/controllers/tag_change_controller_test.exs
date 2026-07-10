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

  defp tag_change_fixture!(user) do
    image = image_fixture()

    # The tag changeset requires at least 3 tags, so the update keeps the
    # fixture's "safe" tag and adds two more.
    {:ok, _} =
      Images.update_tags(image, attribution(user), %{
        "old_tag_input" => "safe",
        "tag_input" => "safe, added test tag, other added tag"
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

    test "resource_type and resource_id params only change the heading", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      other_image = image_fixture()

      # NOTE: resource_type/resource_id are display-only - TagChanges.load
      # compiles a search query from the "tcq" param alone, so pointing at
      # a different image still lists every tag change.
      conn =
        get(conn, ~p"/tag_changes?#{[resource_type: "image", resource_id: other_image.id]}")

      response = html_response(conn, 200)

      assert response =~ "Showing tag changes for"
      assert response =~ "image ##{other_image.id}"
      assert response =~ "added test tag"
      assert response =~ ~p"/images/#{image}"
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

    test "a non-integer id raises a cast error", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      assert_raise Ecto.Query.CastError, fn ->
        delete(conn, ~p"/tag_changes/not-an-integer", %{"redirect" => "/"})
      end
    end
  end
end
