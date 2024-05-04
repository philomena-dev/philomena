defmodule PhilomenaWeb.Conversation.MessageController do
  use PhilomenaWeb, :controller

  alias Philomena.Conversations.{Conversation, Message}
  alias Philomena.Conversations
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :show

  plug :load_and_authorize_resource,
    model: Conversation,
    id_name: "conversation_id",
    id_field: "slug",
    persisted: true

  def create(conn, %{"message" => message_params}) do
    conversation = conn.assigns.conversation
    user = conn.assigns.current_user

    case Conversations.create_message(conversation, user, message_params) do
      {:ok, %{message: message}} ->
        if not message.approved do
          Conversations.report_non_approved(message.conversation_id)
        end

        count =
          Message
          |> where(conversation_id: ^conversation.id)
          |> Repo.aggregate(:count, :id)

        page =
          Float.ceil(count / 25)
          |> round()

        conn
        |> put_flash(:info, "Message successfully sent.")
        |> redirect(to: ~p"/conversations/#{conversation}?#{[page: page]}")

      _error ->
        conn
        |> put_flash(:error, "There was an error posting your message")
        |> redirect(to: ~p"/conversations/#{conversation}")
    end
  end
end
