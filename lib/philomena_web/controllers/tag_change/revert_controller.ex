defmodule PhilomenaWeb.TagChange.RevertController do
  use PhilomenaWeb, :controller

  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def create(conn, %{"ids" => ids}) when is_list(ids) do
    attributes = conn.assigns.attributes

    attributes = %{
      ip: attributes[:ip],
      fingerprint: attributes[:fingerprint],
      user_id: attributes[:user].id
    }

    case TagChanges.mass_revert(ids, attributes) do
      {:ok, _affected_tag_changes, total_tags_affected} ->
        conn
        |> put_flash(
          :info,
          "Successfully reverted #{length(ids)} tag changes with " <>
            "#{total_tags_affected} tags actually updated."
        )
        |> moderation_log(
          details: &log_details/2,
          data: %{user: conn.assigns.current_user, count: length(ids)}
        )
        |> redirect(external: conn.assigns.referrer)

      _error ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)
    end
  end

  # Handles the case where no tag changes were selected for submission at all.
  def create(conn, _payload) do
    conn
    |> put_flash(:error, "No tag changes selected.")
    |> redirect(external: conn.assigns.referrer)
  end

  defp verify_authorized(conn, _params) do
    if Canada.Can.can?(conn.assigns.current_user, :revert, TagChange) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, data) do
    %{body: "Reverted #{data.count} tag changes", subject_path: ~p"/profiles/#{data.user}"}
  end
end
