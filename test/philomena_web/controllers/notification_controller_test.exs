defmodule PhilomenaWeb.NotificationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Forums
  alias Philomena.Images
  alias Philomena.Notifications

  test "anonymous GET /notifications redirects to the login page", %{conn: conn} do
    conn = get(conn, ~p"/notifications")

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "GET /notifications with no notifications renders the empty notification area",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    response = html_response(get(conn, ~p"/notifications"), 200)

    assert response =~ "Notification Area - Derpibooru"
    refute response =~ "View category ("
  end

  test "GET /notifications groups unread notifications by category", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

    # forum_topic: user watches a forum, someone posts a topic in it
    forum = forum_fixture()
    {:ok, _} = Forums.create_subscription(forum, user)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.create_forum_topic_notification(author, topic)

    # image_comment: user watches an image, someone comments on it
    image = image_fixture()
    {:ok, _} = Images.create_subscription(image, user)
    comment = comment_fixture(image, author)
    {:ok, 1} = Notifications.create_image_comment_notification(author, image, comment)

    response = html_response(get(conn, ~p"/notifications"), 200)

    assert response =~ "New topics"
    assert response =~ topic.title
    assert response =~ ~p"/notifications/categories/forum_topic"
    assert response =~ "New replies on images"
    assert response =~ ~p"/notifications/categories/image_comment"
  end

  test "GET /notifications does not show other users' notifications", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    forum = forum_fixture()
    recipient = confirmed_user_fixture()
    {:ok, _} = Forums.create_subscription(forum, recipient)
    author = confirmed_user_fixture()
    topic = topic_fixture(forum, author)
    {:ok, 1} = Notifications.create_forum_topic_notification(author, topic)

    response = html_response(get(conn, ~p"/notifications"), 200)

    refute response =~ topic.title
  end

  test "DELETE /notifications/:id is routed but has no controller action", %{conn: conn} do
    # NOTE: the router declares `resources "/notifications", only:
    # [:index, :delete]` but NotificationController defines no delete/2, so
    # the route 500s for everyone. (KNOWN-ODDITIES.md)
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    assert_raise UndefinedFunctionError, ~r/delete\/2/, fn ->
      delete(conn, ~p"/notifications/1")
    end
  end
end
