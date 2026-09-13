defmodule PhilomenaWeb.DuplicateReport.AcceptController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_accept(conn.assigns.actor, id) do
      {:ok, _duplicate_report} ->
        conn
        |> put_flash(:info, "Successfully accepted report.")
        |> redirect(to: ~p"/duplicate_reports")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to accept report! Maybe someone else already accepted it.")
        |> redirect(to: ~p"/duplicate_reports")

      error ->
        error
    end
  end
end
