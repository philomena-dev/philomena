defmodule PhilomenaWeb.TagChange.FullRevertController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.TagChanges.TagChange
  alias Philomena.TagChanges
  alias PhilomenaWeb.IntegerId
  alias Philomena.Repo

  plug :verify_authorized
  plug PhilomenaWeb.UserAttributionPlug

  def create(%{assigns: %{attributes: attributes}} = conn, params) do
    attributes = %{
      ip: to_string(attributes[:ip]),
      fingerprint: attributes[:fingerprint],
      user_id: attributes[:user].id,
      batch_size: attributes[:batch_size] || 100
    }

    case revert_target(params) do
      nil ->
        conn
        |> put_flash(:error, "Couldn't revert those tag changes!")
        |> redirect(external: conn.assigns.referrer)

      target ->
        TagChanges.full_revert(Map.put(target, :attributes, attributes))

        conn
        |> put_flash(:info, "Reversion of tag changes enqueued.")
        |> moderation_log(
          details: &log_details/2,
          data: %{user: conn.assigns.current_user, params: params}
        )
        |> redirect(external: conn.assigns.referrer)
    end
  end

  defp revert_target(%{"user_id" => user_id}), do: %{user_id: user_id}
  defp revert_target(%{"ip" => ip}), do: %{ip: ip}
  defp revert_target(%{"fingerprint" => fp}), do: %{fingerprint: fp}
  defp revert_target(_params), do: nil

  defp verify_authorized(conn, _params) do
    if Canada.Can.can?(conn.assigns.current_user, :revert, TagChange) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, data) do
    {subject, subject_path} =
      case data.params do
        %{"user_id" => user_id} ->
          log_user(user_id)

        %{"ip" => ip} ->
          {"ip #{ip}", ~p"/ip_profiles/#{ip}"}

        %{"fingerprint" => fp} ->
          {"fingerprint #{fp}", ~p"/fingerprint_profiles/#{fp}"}
      end

    %{body: "Reverted all tag changes for #{subject}", subject_path: subject_path}
  end

  # The revert is enqueued for whatever id was named, so the log entry has to
  # survive an id that names no user.
  defp log_user(user_id) do
    case load_user(user_id) do
      nil -> {"user #{user_id}", ~p"/tag_changes"}
      user -> {"user #{user.name}", ~p"/profiles/#{user}"}
    end
  end

  defp load_user(user_id) do
    case IntegerId.parse(user_id) do
      {:ok, id} -> Repo.get(User, id)
      :error -> nil
    end
  end
end
