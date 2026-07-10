defmodule PhilomenaWeb.Conversation.MessageControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ConversationsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Conversations
  alias Philomena.Repo

  test "anonymous POST redirects to the login page", %{conn: conn} do
    conn = post(conn, ~p"/conversations/dummy-slug/messages", %{})

    assert redirected_to(conn) == ~p"/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  test "POST as a participant creates the message and redirects to the last page",
       %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    sender = confirmed_user_fixture()
    conversation = conversation_fixture(sender, user)

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "A reply from the recipient"}
      })

    assert redirected_to(conn) == ~p"/conversations/#{conversation}?#{[page: 1]}"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Message successfully sent."

    assert Conversations.count_messages(conversation) == 2

    # a new message marks both sides unread again
    conversation = Repo.reload!(conversation)
    refute conversation.from_read
    refute conversation.to_read
  end

  test "POST with an empty body redirects back with an error flash", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), user)

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => ""}
      })

    assert redirected_to(conn) == ~p"/conversations/#{conversation}"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "There was an error posting your message"

    assert Conversations.count_messages(conversation) == 1
  end

  test "POST as a non-participant moderator creates the message", %{conn: conn} do
    # NOTE: create maps to the :show ability, so any moderator can post
    # into any conversation.
    %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "Moderator interjection"}
      })

    assert redirected_to(conn) == ~p"/conversations/#{conversation}?#{[page: 1]}"
    assert Conversations.count_messages(conversation) == 2
  end

  test "POST as a non-participant redirects to / with the authorization flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conversation = conversation_fixture(confirmed_user_fixture(), confirmed_user_fixture())

    conn =
      post(conn, ~p"/conversations/#{conversation}/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    assert Conversations.count_messages(conversation) == 1
  end

  test "POST for an unknown conversation redirects to / with the authorization flash",
       %{conn: conn} do
    # Canary sends the nil resource down the unauthorized path
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations/unknown-slug/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "POST as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn =
      post(conn, ~p"/conversations/dummy-slug/messages", %{
        "message" => %{"body" => "Should not appear"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
