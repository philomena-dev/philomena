defmodule PhilomenaWeb.PostControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Posts.Post
  alias Philomena.Repo

  setup do
    SearchHelpers.clear_index!(Post)
    :ok
  end

  defp topic_with_post(forum, body) do
    topic = topic_fixture(forum)
    post_fixture(topic, nil, %{"body" => body})
  end

  describe "GET /posts" do
    test "renders recent posts for anonymous users", %{conn: conn} do
      topic = topic_fixture(forum_fixture())
      _post = post_fixture(topic, nil, %{"body" => "Test searchable post body"})
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/posts")
      response = html_response(conn, 200)

      assert response =~ "Posts - Derpibooru"
      assert response =~ "Test searchable post body"
      assert response =~ topic.title
    end

    test "does not show restricted-forum posts to anonymous users", %{conn: conn} do
      staff_forum = forum_fixture(access_level: "staff")
      _post = topic_with_post(staff_forum, "Test staff-only post body")
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/posts")
      response = html_response(conn, 200)

      refute response =~ "Test staff-only post body"
    end

    test "shows restricted-forum posts to moderators", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      staff_forum = forum_fixture(access_level: "staff")
      _post = topic_with_post(staff_forum, "Test staff-only post body")
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/posts")
      response = html_response(conn, 200)

      assert response =~ "Test staff-only post body"
    end

    test "does not show hidden posts to anonymous users", %{conn: conn} do
      forum = forum_fixture()
      post = topic_with_post(forum, "Test hidden post body")

      post
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/posts")
      response = html_response(conn, 200)

      refute response =~ "Test hidden post body"
    end

    test "filters posts with the pq parameter", %{conn: conn} do
      forum = forum_fixture()
      _matching = topic_with_post(forum, "Test grapefruit post")
      _other = topic_with_post(forum, "Test kumquat post")
      SearchHelpers.reindex_all!(Post)

      conn = get(conn, ~p"/posts?pq=grapefruit")
      response = html_response(conn, 200)

      assert response =~ "Test grapefruit post"
      refute response =~ "Test kumquat post"
    end

    test "renders an error for an invalid pq query", %{conn: conn} do
      conn = get(conn, ~p"/posts?pq=created_at.gte:not-a-date")
      response = html_response(conn, 200)

      assert response =~ "Posts - Derpibooru"
    end
  end
end
