defmodule PhilomenaWeb.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  plug PhilomenaWeb.UserAttributionPlug

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case TagChanges.revert_tag_changes(conn.assigns.actor, params["ids"]) do
      {:ok, tag_changes} ->
        conn
        |> put_flash(:info, "Successfully reverted #{length(tag_changes)} tag changes.")
        |> redirect(external: conn.assigns.referrer)

      {:error, :unauthorized} = error ->
        error

      _error ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)
    end
  end
end
