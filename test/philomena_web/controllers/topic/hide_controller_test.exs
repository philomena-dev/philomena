defmodule PhilomenaWeb.Topic.HideControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Topics
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{forum: forum, topic: topic}
  end

  defp hidden_topic(topic) do
    {:ok, topic} =
      Topics.hide_topic(topic, "Spam", Philomena.UsersFixtures.moderator_user_fixture())

    topic
  end

  describe "POST /forums/:forum_id/topics/:topic_id/hide" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == ~p"/sessions/new"
      refute Repo.reload!(topic).hidden_from_users
    end

    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.reload!(topic).hidden_from_users
    end

    test "as a moderator hides the topic and records the reason and deleter",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn, user: user} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
          "topic" => %{"deletion_reason" => "Rule violation"}
        })

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully deleted!"

      topic = Repo.reload!(topic)
      assert topic.hidden_from_users
      assert topic.deletion_reason == "Rule violation"
      assert topic.deleted_by_id == user.id
    end

    # Failure path: hide_changeset requires deletion_reason, so a blank reason
    # makes the hide_topic Multi fail - returning a 4-tuple
    # ({:error, :topic, changeset, changes}) that the controller's
    # {:error, _changeset} branch does not match, raising CaseClauseError (500).
    # NOTE: KNOWN-ODDITIES.md
    test "with a blank deletion reason raises CaseClauseError",
         %{conn: conn, forum: forum, topic: topic} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      assert_raise CaseClauseError,
                   ~r/no case clause matching:\s*\{:error, :topic,.*deletion_reason: \{"can't be blank"/s,
                   fn ->
                     post(conn, ~p"/forums/#{forum}/topics/#{topic}/hide", %{
                       "topic" => %{"deletion_reason" => ""}
                     })
                   end

      refute Repo.reload!(topic).hidden_from_users
    end

    test "redirects to / with the not-found flash for an unknown topic",
         %{conn: conn, forum: forum} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/hide", %{
          "topic" => %{"deletion_reason" => "Spam"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "DELETE /forums/:forum_id/topics/:topic_id/hide" do
    test "redirects anonymous users to the login page", %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(topic)

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == ~p"/sessions/new"
      assert Repo.reload!(topic).hidden_from_users
    end

    # A regular user cannot even load a hidden topic (LoadTopicPlug rejects it
    # before the authorize_resource :hide check), so the not-authorized redirect
    # comes from the load plug.
    test "rejects a regular user with the authorization flash",
         %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(topic)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(topic).hidden_from_users
    end

    test "as a moderator restores the topic", %{conn: conn, forum: forum, topic: topic} do
      topic = hidden_topic(topic)
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/forums/#{forum}/topics/#{topic}/hide")

      assert redirected_to(conn) == ~p"/forums/#{forum}/topics/#{topic}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Topic successfully restored!"

      topic = Repo.reload!(topic)
      refute topic.hidden_from_users
      assert topic.deleted_by_id == nil
      assert topic.deletion_reason == ""
    end
  end
end
