defmodule PhilomenaWeb.Api.Json.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Topics

  describe "GET /api/v1/json/posts/:id" do
    test "shows a signed post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "A signed post"})

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      %{"post" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => post.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed post",
               "created_at" => DateTime.to_iso8601(post.created_at),
               "updated_at" => DateTime.to_iso8601(post.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "hides the author of an anonymous post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "Anon post", "anonymous" => "true"})

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert %{"post" => %{"user_id" => nil, "author" => author}} = json_response(conn, 200)
      assert author =~ ~r/\ABackground Pony #[0-9A-F]{4}\z/
    end

    test "nulls out the body of a hidden post but stays 200", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, user, %{"body" => "Rule-breaking post"})

      {:ok, _} = Posts.hide_post(post, %{"deletion_reason" => "spam"}, moderator)

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert %{"post" => %{"body" => nil, "edited_at" => nil, "author" => author}} =
               json_response(conn, 200)

      assert author == user.name
    end

    test "returns 404 for a destroyed post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, _} = Posts.destroy_post(post)

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post in a hidden topic", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, _} = Topics.hide_topic(topic, "spam", moderator)

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for a post in a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      conn = get(conn, ~p"/api/v1/json/posts/#{post.id}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/posts/#{0}")

      assert json_response(conn, 404) == %{"error" => "Not found"}
    end

    test "raises for a non-integer id", %{conn: conn} do
      # NOTE: the id is interpolated into the query without casting, so a
      # non-integer id becomes a 500 rather than a 404.
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/api/v1/json/posts/not-a-number")
      end
    end
  end
end
