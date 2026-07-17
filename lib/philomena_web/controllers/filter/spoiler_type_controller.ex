defmodule PhilomenaWeb.Filter.SpoilerTypeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.RequireUserPlug

  def update(conn, %{"settings" => settings_params}) when is_map(settings_params) do
    case Users.update_spoiler_type(conn.assigns.current_user, settings_params) do
      {:ok, settings} ->
        conn
        |> put_flash(:info, "Changed spoiler type to #{settings.spoiler_type}")
        |> redirect(external: conn.assigns.referrer)

      {:error, _changeset} ->
        update_failed(conn)
    end
  end

  def update(conn, _params), do: update_failed(conn)

  defp update_failed(conn) do
    conn
    |> put_flash(:error, "Couldn't change spoiler type!")
    |> redirect(external: conn.assigns.referrer)
  end
end
