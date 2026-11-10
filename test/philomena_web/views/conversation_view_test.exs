defmodule PhilomenaWeb.ConversationViewTest do
  use ExUnit.Case, async: true

  alias Philomena.Conversations.Conversation
  alias PhilomenaWeb.ConversationView

  @conversation %Conversation{
    slug: "7",
    from_id: 1,
    from: :sender,
    from_read: true,
    from_hidden: false,
    to_id: 2,
    to: :recipient,
    to_read: false,
    to_hidden: true
  }

  test "the other party, read and hidden state follow the side of the viewer" do
    assert ConversationView.other_party(%{id: 1}, @conversation) == :recipient
    assert ConversationView.other_party(%{id: 2}, @conversation) == :sender

    assert ConversationView.read_by?(%{id: 1}, @conversation)
    refute ConversationView.read_by?(%{id: 2}, @conversation)
    refute ConversationView.read_by?(%{id: 3}, @conversation)

    refute ConversationView.hidden_by?(%{id: 1}, @conversation)
    assert ConversationView.hidden_by?(%{id: 2}, @conversation)
    refute ConversationView.hidden_by?(%{id: 3}, @conversation)
  end

  test "an unread conversation is a warning row" do
    assert ConversationView.conversation_class(%{id: 1}, @conversation) == nil
    assert ConversationView.conversation_class(%{id: 2}, @conversation) == "table-warning"
  end

  test "the last message links to the page holding it" do
    assert ConversationView.last_message_path(@conversation, 26) == "/conversations/7?page=2"
  end
end
