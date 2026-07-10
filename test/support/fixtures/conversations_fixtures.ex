defmodule Philomena.ConversationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Conversations` context.
  """

  alias Philomena.Conversations

  def unique_conversation_title, do: "Test Conversation #{System.unique_integer([:positive])}"

  @doc """
  Creates a conversation from `from` to `to` with one initial message.

  `attrs` are merged into the string-keyed params map the way the
  conversation controller would submit them; pass
  `"messages" => %{"0" => %{"body" => ...}}` to override the message body.

  Returns the conversation with `messages: [first_message]` loaded.
  """
  def conversation_fixture(from, to, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "recipient" => to.name,
        "title" => unique_conversation_title(),
        "messages" => %{"0" => %{"body" => "Test message body"}}
      })

    {:ok, conversation} = Conversations.create_conversation(from, attrs)

    conversation
  end

  @doc """
  Creates a reply message in `conversation` from `user`.
  """
  def message_fixture(conversation, user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"body" => "Test reply body"})

    {:ok, message} = Conversations.create_message(conversation, user, attrs)

    message
  end
end
