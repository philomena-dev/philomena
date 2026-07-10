defmodule PhilomenaWeb.Topic.Post.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Posts
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    post = post_fixture(topic)

    %{forum: forum, topic: topic, post: post}
  end

  defp post_anchor(forum, topic, post) do
    ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"
  end

  defp hidden_post(post) do
    {:ok, post} =
      Posts.hide_post(
        post,
        %{"deletion_reason" => "Spam"},
        Philomena.UsersFixtures.moderator_user_fixture()
      )

    post
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts/:post_id/hide" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide", %{
          "post" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(post).hidden_from_users
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide", %{
          "post" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(post).hidden_from_users
    end

    test "as a moderator hides the post and redirects to its anchor",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide", %{
          "post" => %{"deletion_reason" => "Rule violation"}
        })

      assert redirected_to(conn) == post_anchor(forum, topic, post)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully deleted."

      post = Repo.reload!(post)
      assert post.hidden_from_users
      assert post.deletion_reason == "Rule violation"
    end

    # Failure path: hide_changeset requires deletion_reason, so a blank reason
    # makes the hide_post Multi fail - returning a 4-tuple the controller's
    # {:error, _changeset} branch does not match, raising CaseClauseError (500).
    # NOTE: KNOWN-ODDITIES.md
    test "with a blank deletion reason raises CaseClauseError",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise CaseClauseError,
                   ~r/no case clause matching:\s*\{:error, :post,.*deletion_reason: \{"can't be blank"/s,
                   fn ->
                     post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide", %{
                       "post" => %{"deletion_reason" => ""}
                     })
                   end

      refute Repo.reload!(post).hidden_from_users
    end

    test "for an unknown post_id redirects with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/hide", %{
          "post" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the post_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer post_id raises CastError",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/not-a-number/hide", %{
          "post" => %{"deletion_reason" => "Spam"}
        })
      end
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/posts/:post_id/hide" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      post = hidden_post(post)

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(post).hidden_from_users
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      post = hidden_post(post)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(post).hidden_from_users
    end

    test "as a moderator restores the post",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      post = hidden_post(post)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/hide")

      assert redirected_to(conn) == post_anchor(forum, topic, post)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully restored."
      refute Repo.reload!(post).hidden_from_users
    end
  end
end
