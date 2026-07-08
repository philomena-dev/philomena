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

    # Failure path: the target forum id is interpolated straight into the
    # topic's forum_id via a plain put_change with no foreign_key_constraint,
    # so a nonexistent target raises Ecto.ConstraintError (a 500). The
    # controller's {:error, _changeset} branch is unreachable: move_topic runs
    # a Multi, whose failure would be a 4-tuple the branch doesn't match.
    # NOTE: KNOWN-ODDITIES.md
    test "moving to a nonexistent forum id raises a constraint error",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Ecto.ConstraintError, fn ->
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => "999999999"}
        })
      end
    end

    # NOTE: create/2 only matches %{"topic" => %{"target_forum_id" => _}}, so a
    # request without those params raises Phoenix.ActionClauseError (a 500).
    test "a request without the target_forum_id param raises ActionClauseError",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{})
      end
    end

    # NOTE: the target_forum_id is fed to String.to_integer/1, so a non-integer
    # value raises ArgumentError (a 500).
    test "a non-integer target_forum_id raises ArgumentError",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise ArgumentError, ~r/not a textual representation of an integer/, fn ->
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/move", %{
          "topic" => %{"target_forum_id" => "not-a-number"}
        })
      end
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
