defmodule PhilomenaWeb.Topic.MoveControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    target_forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, target_forum: target_forum, topic: topic}
  end

  describe "POST /forums/:forum_id/topics/:topic_id/move" do
    test "redirects anonymous users to the login page",
         %{conn: conn, forum: forum, target_forum: target_forum, topic: topic} do
      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => to_string(target_forum.id)}
        })

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."

      assert Repo.reload!(topic).forum_id == forum.id
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, target_forum: target_forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => to_string(target_forum.id)}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).forum_id == forum.id
    end

    test "as a moderator moves the topic and redirects to it in the target forum",
         %{conn: conn, forum: forum, target_forum: target_forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => to_string(target_forum.id)}
        })

      assert redirected_to(conn) == ~p"/forums/#{target_forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully moved!"
      assert Repo.reload!(topic).forum_id == target_forum.id
    end

    # NOTE: move_changeset now declares the FK constraint and move_topic
    # normalizes the Multi failure, so a nonexistent target forum redirects back
    # to the topic with the failure flash instead of raising Ecto.ConstraintError.
    test "moving to a nonexistent forum id redirects back with the failure flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => "999999999"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to move the topic!"
      assert Repo.reload!(topic).forum_id == forum.id
    end

    # NOTE: a request without the target_forum_id param now takes the fallback
    # create/2 clause and redirects back with the failure flash rather than
    # raising ActionClauseError.
    test "a request without the target_forum_id param redirects back with the failure flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{})

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to move the topic!"
      assert Repo.reload!(topic).forum_id == forum.id
    end

    # NOTE: the target_forum_id is now parsed with IntegerId.parse, so a
    # non-integer value redirects back with the failure flash rather than
    # raising ArgumentError.
    test "a non-integer target_forum_id redirects back with the failure flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => "not-a-number"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Unable to move the topic!"
      assert Repo.reload!(topic).forum_id == forum.id
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum, target_forum: target_forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/move", %{
          "topic" => %{"target_forum_id" => to_string(target_forum.id)}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end
end
