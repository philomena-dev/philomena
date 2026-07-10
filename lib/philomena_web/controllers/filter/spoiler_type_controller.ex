defmodule PhilomenaWeb.Filter.SpoilerTypeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  plug PhilomenaWeb.RequireUserPlug

  def update(conn, %{"user" => user_params}) when is_map(user_params) do
    case Users.update_spoiler_type(conn.assigns.current_user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Changed spoiler type to #{user.spoiler_type}")
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
