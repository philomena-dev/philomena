defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Topics

  describe "GET /api/v1/json/forums/:forum_id/topics/:topic_id/posts" do
    test "lists posts in topic-position order", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user, %{"posts" => %{"0" => %{"body" => "First post"}}})
      reply = post_fixture(topic, user, %{"body" => "Second post"})

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts")

      assert %{"posts" => [first, second], "total" => 2} = json_response(conn, 200)

      assert %{"body" => "First post", "author" => author} = first
      assert author == user.name
      assert %{"body" => "Second post", "id" => reply_id} = second
      assert reply_id == reply.id
    end

    test "includes hidden posts with a null body", %{conn: conn} do
      user = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      reply = post_fixture(topic, user, %{"body" => "Rule-breaking reply"})

      {:ok, _} = Posts.hide_post(reply, %{"deletion_reason" => "spam"}, moderator)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts")

      # NOTE: hidden posts are not filtered from the index; they render with
      # a null body.
      assert %{"posts" => [_first, hidden], "total" => 2} = json_response(conn, 200)
      assert %{"body" => nil, "id" => hidden_id} = hidden
      assert hidden_id == reply.id
    end

    test "paginates in fixed windows of 25 by topic position", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      for n <- 1..25, do: post_fixture(topic, user, %{"body" => "Reply number #{n}"})

      conn2 = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?page=2")

      # NOTE: the page window is hardcoded to 25 posts; per_page is ignored.
      assert %{"posts" => [last], "total" => 26} = json_response(conn2, 200)
      assert %{"body" => "Reply number 25"} = last
    end

    test "crashes for an unknown topic or forum", %{conn: conn} do
      forum = forum_fixture()

      # NOTE: the total is taken from the first returned post's topic, so an
      # empty page (unknown topic, unknown forum, or a page past the end)
      # crashes on hd([]) with a 500 instead of returning a 404 or an empty
      # list. Logged in KNOWN-ODDITIES.md.
      assert_raise ArgumentError, ~r/empty list/, fn ->
        get(conn, ~p"/api/v1/json/forums/#{forum}/topics/nonexistent/posts")
      end
    end

    test "crashes for a page past the last post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      assert_raise ArgumentError, ~r/empty list/, fn ->
        get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts?page=2")
      end
    end
  end

  describe "GET /api/v1/json/forums/:forum_id/topics/:topic_id/posts/:id" do
    test "shows a post", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      post = post_fixture(topic, user, %{"body" => "A signed reply"})

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      %{"post" => body} = json_response(conn, 200)

      # NOTE: the avatar of a user without an uploaded avatar is a generated
      # SVG data URI, so it is asserted by shape only.
      {avatar, body} = Map.pop(body, "avatar")
      assert is_binary(avatar)

      assert body == %{
               "id" => post.id,
               "user_id" => user.id,
               "author" => user.name,
               "body" => "A signed reply",
               "created_at" => DateTime.to_iso8601(post.created_at),
               "updated_at" => DateTime.to_iso8601(post.updated_at),
               "edited_at" => nil,
               "edit_reason" => nil
             }
    end

    test "returns 404 for a destroyed post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, _} = Posts.destroy_post(post)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      # NOTE: the 404 body is empty text/plain, not a JSON error object.
      assert response(conn, 404) == ""
      assert response_content_type(conn, :text)
    end

    test "returns 404 for a post in a hidden topic", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      {:ok, _} = Topics.hide_topic(topic, "spam", moderator)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      assert response(conn, 404) == ""
    end

    test "returns 404 for a post under the wrong topic slug", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      other_topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{other_topic}/posts/#{post.id}")

      assert response(conn, 404) == ""
    end

    test "returns 404 for a post in a restricted forum", %{conn: conn} do
      forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum)
      post = post_fixture(topic, nil)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{post.id}")

      assert response(conn, 404) == ""
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      conn = get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/#{0}")

      assert response(conn, 404) == ""
    end

    test "raises for a non-integer id", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      # NOTE: the id is interpolated into the query without casting, so a
      # non-integer id becomes a 500 rather than a 404.
      assert_raise Ecto.Query.CastError, fn ->
        get(conn, ~p"/api/v1/json/forums/#{forum}/topics/#{topic}/posts/not-a-number")
      end
    end
  end
end
