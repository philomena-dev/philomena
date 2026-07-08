defmodule PhilomenaWeb.Topic.Post.ApproveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.PostsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  # A post authored by a fresh (untrusted) user containing an external link is
  # not auto-approved on creation (see Philomena.Schema.Approval).
  defp unapproved_post(topic) do
    post =
      post_fixture(topic, confirmed_user_fixture(), %{
        "body" => "check this out https://spam.example/"
      })

    refute post.approved
    post
  end

  defp post_anchor(forum, topic, post) do
    ~p"/forums/#{forum}/topics/#{topic}?#{[post_id: post.id]}" <> "#post_#{post.id}"
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts/:post_id/approve" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(post).approved
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(post).approved
    end

    test "as a moderator approves the post",
         %{conn: conn, forum: forum, topic: topic} do
      post = unapproved_post(topic)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert redirected_to(conn) == post_anchor(forum, topic, post)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully approved."
      assert Repo.reload!(post).approved
    end

    # Approving an already-approved post still reports success (approve_changeset
    # sets the column unconditionally; there is no verify_not_approved guard).
    test "approving an already-approved post still succeeds",
         %{conn: conn, forum: forum, topic: topic} do
      post = post_fixture(topic)
      assert post.approved
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/approve")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Post successfully approved."
      assert Repo.reload!(post).approved
    end

    # Failure path: the only reachable failure surface is an unknown post —
    # load_and_authorize_resource authorizes the nil resource, which no
    # moderator rule matches, so it redirects with the authorization flash.
    test "for an unknown post_id redirects with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/approve")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: the post_id is interpolated into the load query, so a non-integer
    # value raises Ecto.Query.CastError (a 500).
    test "for a non-integer post_id raises CastError",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.Query.CastError, fn ->
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/not-a-number/approve")
      end
    end
  end
end
