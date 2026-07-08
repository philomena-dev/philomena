defmodule PhilomenaWeb.Notification.CategoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ForumsFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Notifications

  test "anonymous GET redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/notifications/categories/forum_topic")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET lists the user's unread notifications in the category", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    {:ok, _} = Forums.create_subscription(forum, user)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.create_forum_topic_notification(author, topic)

    response = html_response(get(conn, ~p"/notifications/categories/forum_topic"), 200)

    assert response =~ "Notification Area - Derpibooru"
    assert response =~ "New topics"
    assert response =~ topic.title
  end

  test "GET with no notifications in the category renders the empty message", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/notifications/categories/forum_topic"), 200)

    assert response =~ "You currently have no notifications of this category."
  end

  test "GET with an unknown category id falls back to forum_post", %{conn: conn} do
    # NOTE: the category parser defaults every unrecognized id to
    # :forum_post rather than 404ing.
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, _} = Philomena.Topics.create_subscription(topic, user)
    post = Philomena.PostsFixtures.post_fixture(topic, author)
    {:ok, 1} = Notifications.create_forum_post_notification(author, topic, post)

    response = html_response(get(conn, ~p"/notifications/categories/bogus-category"), 200)

    assert response =~ "New replies in topics"
    assert response =~ topic.title
  end
end
