defmodule PhilomenaWeb.Forum.SubscriptionController do
  use PhilomenaWeb, :controller

  alias Philomena.Forums

  action_fallback PhilomenaWeb.FallbackController

  plug :put_view, PhilomenaWeb.SubscriptionView

  def create(conn, params) do
    case Forums.create_forum_subscription(conn.assigns.actor, params["forum_id"]) do
      {:ok, forum} ->
        render(conn, "_subscription.html",
          path: ~p"/forums/#{forum}/subscription",
          watching: true,
          layout: false
        )

      {:error, %Ecto.Changeset{}} ->
        render(conn, "_error.html", layout: false)

      {:error, _} = error ->
        error
    end
  end

  def delete(conn, params) do
    with {:ok, forum} <- Forums.delete_forum_subscription(conn.assigns.actor, params["forum_id"]) do
      render(conn, "_subscription.html",
        path: ~p"/forums/#{forum}/subscription",
        watching: false,
        layout: false
      )
    end
  end
end
