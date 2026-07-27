defmodule PhilomenaWeb.TagChange.FullRevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges

  plug PhilomenaWeb.UserAttributionPlug

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, params) do
    case TagChanges.full_revert(conn.assigns.actor, params) do
      {:ok, _target} ->
        conn
        |> put_flash(:info, "Reversion of tag changes enqueued.")
        |> redirect(external: conn.assigns.referrer)

      {:error, :unauthorized} = error ->
        error

      {:error, :invalid_target} ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)
    end
  end
end
