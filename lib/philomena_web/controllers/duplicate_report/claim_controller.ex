defmodule PhilomenaWeb.DuplicateReport.ClaimController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_claim(conn.assigns.actor, id) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Successfully claimed report.")
        |> redirect(to: ~p"/duplicate_reports")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to claim report.")
        |> redirect(to: ~p"/duplicate_reports")

      error ->
        error
    end
  end

  def delete(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.delete_duplicate_report_claim(conn.assigns.actor, id) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Successfully released report.")
        |> redirect(to: ~p"/duplicate_reports")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to release report.")
        |> redirect(to: ~p"/duplicate_reports")

      error ->
        error
    end
  end
end
