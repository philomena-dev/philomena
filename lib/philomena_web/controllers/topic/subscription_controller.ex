defmodule PhilomenaWeb.Topic.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics

  action_fallback PhilomenaWeb.FallbackController

  plug :put_view, PhilomenaWeb.SubscriptionView

  def create(conn, params) do
    case Topics.create_topic_subscription(
           conn.assigns.actor,
           params["forum_id"],
           params["topic_id"]
         ) do
      {:ok, target} ->
        render(conn, "_subscription.html", target: target, watching: true, layout: false)

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, target} <-
           Topics.delete_topic_subscription(
             conn.assigns.actor,
             params["forum_id"],
             params["topic_id"]
           ) do
      render(conn, "_subscription.html", target: target, watching: false, layout: false)
    end
  end
end
