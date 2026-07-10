defmodule PhilomenaWeb.Topic.Post.HistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Posts

  describe "GET /forums/:forum_id/topics/:topic_id/posts/:post_id/history" do
    test "renders the edit history for anonymous users", %{conn: conn} do
      forum = forum_fixture()
      author = confirmed_user_fixture()

      topic =
        topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "Original post body"}}})

      [post] = topic.posts

      {:ok, _} =
        Posts.update_post(post, author, %{
          "body" => "Original post body plus an edit",
          "edit_reason" => "typo fix"
        })

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/history")
      response = html_response(conn, 200)

      assert response =~ "Post History for Post #{post.id} - #{topic.title} - Forums"
      assert response =~ "Viewing last 25 versions of post by"
      assert response =~ author.name
      # The version body is rendered as a character-level diff against the
      # current body, so only the shared prefix survives contiguously; the
      # edit's addition is wrapped in an <ins> tag.
      assert response =~ "Original post body"
      assert response =~ "<ins class=\"differ\">"
    end

    test "renders an empty history for a never-edited post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      [post] = topic.posts

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/history")
      response = html_response(conn, 200)

      assert response =~ "Post History for Post #{post.id} - #{topic.title} - Forums"
    end

    test "redirects to / for an unknown post", %{conn: conn} do
      forum = forum_fixture()
      topic = topic_fixture(forum)

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/history")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown forum", %{conn: conn} do
      conn = get(conn, ~p"/forums/nonexistent/topics/nonexistent/posts/1/history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end
  end
end
