defmodule PhilomenaWeb.DuplicateReport.RejectController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"duplicate_report_id" => id}) do
    case DuplicateReports.create_duplicate_report_reject(conn.assigns.actor, id) do
      {:ok, _report} ->
        conn
        |> put_flash(:info, "Successfully rejected report.")
        |> redirect(to: ~p"/duplicate_reports")

      {:error, %Ecto.Changeset{}} ->
        conn
        |> put_flash(:error, "Failed to reject report.")
        |> redirect(to: ~p"/duplicate_reports")

      error ->
        error
    end
  end
end
