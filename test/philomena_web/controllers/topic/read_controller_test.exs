defmodule PhilomenaWeb.Topic.ReadControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  use PhilomenaWeb.SingletonToggleTests

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Notifications
  alias Philomena.Notifications.ForumPostNotification
  alias Philomena.Repo
  alias Philomena.Topics

  # require_authenticated_user halts before the resource loads, so the ids in
  # this path need not exist.
  defp anonymous_path, do: ~p"/forums/dummy/topics/1/read"

  defp read_target(user) do
    forum = forum_fixture()
    topic = topic_fixture(forum)

    %{
      path: ~p"/forums/#{forum}/topics/#{topic}/read",
      arrange!: fn ->
        {:ok, _} = Topics.create_subscription(topic, user)
        author = confirmed_user_fixture()
        post = hd(topic.posts)
        {:ok, 1} = Notifications.create_forum_post_notification(author, topic, post)
      end,
      notification?: fn ->
        Repo.exists?(
          from n in ForumPostNotification,
            where: n.topic_id == ^topic.id and n.user_id == ^user.id
        )
      end
    }
  end

  read_singleton_tests()

  test "POST for an unknown topic redirects to / with the not-found flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()

    conn = post(conn, ~p"/forums/#{forum}/topics/nonexistent-topic/read")

    assert redirected_to(conn) == "/"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Couldn't find what you were looking for!"
  end

  test "POST for a hidden topic still clears the notification", %{conn: conn} do
    # LoadTopicPlug passes show_hidden: true here, so hidden topics can be
    # marked read
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    forum = forum_fixture()
    topic = topic_fixture(forum)
    {:ok, _} = Topics.create_subscription(topic, user)
    {:ok, topic} = Topics.hide_topic(topic, "test hiding", moderator_user_fixture())

    conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/read")

    assert response(conn, 200) == ""
  end
end
