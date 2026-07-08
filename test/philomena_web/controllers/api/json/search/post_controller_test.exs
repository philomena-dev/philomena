defmodule PhilomenaWeb.Api.Json.Search.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  # Characterization tests: these pin the current observable behavior of the
  # endpoint (see CHARACTERIZATION-TESTS.md), they do not specify desired
  # behavior.

  @moduletag :search

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts
  alias Philomena.Posts.Post
  alias Philomena.Topics
  alias PhilomenaQuery.SearchHelpers

  setup do
    SearchHelpers.recreate_index!(Post)
    :ok
  end

  describe "GET /api/v1/json/search/posts" do
    test "finds posts by body", %{conn: conn} do
      user = confirmed_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, user)
      post = post_fixture(topic, user, %{"body" => "chartreuse alpaca"})
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      assert %{"total" => 1, "posts" => [found]} = json_response(conn, 200)
      assert %{"id" => id, "body" => "chartreuse alpaca", "author" => author} = found
      assert id == post.id
      assert author == user.name
    end

    test "excludes hidden posts and posts in restricted forums", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      staff_forum = forum_fixture(access_level: "staff")
      topic = topic_fixture(forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse llama"}}})

      _staff_topic =
        topic_fixture(staff_forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse vicuna"}}})

      hidden = post_fixture(topic, nil, %{"body" => "chartreuse guanaco"})
      {:ok, _} = Posts.hide_post(hidden, %{"deletion_reason" => "spam"}, moderator)
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      assert %{"total" => 1, "posts" => [%{"body" => "chartreuse llama"}]} =
               json_response(conn, 200)
    end

    test "returns a null stub for a matched post in a hidden topic", %{conn: conn} do
      moderator = moderator_user_fixture()
      forum = forum_fixture()
      topic = topic_fixture(forum, nil, %{"posts" => %{"0" => %{"body" => "chartreuse okapi"}}})
      [post] = topic.posts

      {:ok, _} = Topics.hide_topic(topic, "spam", moderator)
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/api/v1/json/search/posts?q=chartreuse")

      # NOTE: hiding a topic does not mark its posts hidden in the index, so
      # they still match searches; the view then nulls every field except the
      # id. Logged in KNOWN-ODDITIES.md.
      assert json_response(conn, 200) == %{
               "total" => 1,
               "posts" => [
                 %{
                   "id" => post.id,
                   "user_id" => nil,
                   "author" => nil,
                   "body" => nil,
                   "created_at" => nil,
                   "updated_at" => nil,
                   "edited_at" => nil,
                   "edit_reason" => nil
                 }
               ]
             }
    end

    test "returns an empty result for a missing query string", %{conn: conn} do
      # NOTE: a missing/empty q compiles to match_none, a 200 with no
      # results — not a 400.
      conn = get(conn, ~p"/api/v1/json/search/posts")

      assert json_response(conn, 200) == %{"posts" => [], "total" => 0}
    end

    test "returns 400 with a JSON error for an unparsable query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/json/search/posts?q=)")

      assert json_response(conn, 400) == %{"error" => "Imbalanced parentheses."}
    end
  end
end
