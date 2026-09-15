defmodule PhilomenaWeb.DuplicateReportController do
  use PhilomenaWeb, :controller

  alias Philomena.DuplicateReports
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Repo

  plug PhilomenaWeb.FilterBannedUsersPlug when action in [:create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]

  plug :load_resource,
    model: DuplicateReport,
    only: [:show],
    preload: [:image, :duplicate_of_image]

  def index(conn, params) do
    case DuplicateReports.list_duplicate_reports(conn.assigns.scrivener, params["dq"] || %{}) do
      {:ok, duplicate_reports, changeset} ->
        render(conn, "index.html",
          title: "Duplicate Reports",
          duplicate_reports: duplicate_reports,
          changeset: changeset,
          layout_class: "layout--wide"
        )

      {:error, changeset} ->
        render(conn, "index.html",
          title: "Duplicate Reports",
          duplicate_reports: nil,
          changeset: changeset,
          layout_class: "layout--wide"
        )
    end
  end

  def create(conn, %{"duplicate_report" => duplicate_report_params})
      when is_map(duplicate_report_params) do
    source = load_image(duplicate_report_params["image_id"])
    target = load_image(duplicate_report_params["duplicate_of_image_id"])

    create_report(conn, source, target, duplicate_report_params)
  end

  def create(conn, _params), do: PhilomenaWeb.NotFoundPlug.call(conn)

  # Without a source image there is nowhere to redirect back to.
  defp create_report(conn, nil, _target, _params),
    do: PhilomenaWeb.NotFoundPlug.call(conn)

  defp create_report(conn, source, nil, _params),
    do: report_failed(conn, source)

  defp create_report(conn, source, target, duplicate_report_params) do
    attributes = conn.assigns.attributes

    case DuplicateReports.create_duplicate_report(
           source,
           target,
           attributes,
           duplicate_report_params
         ) do
      {:ok, duplicate_report} ->
        conn
        |> put_flash(:info, "Duplicate report created successfully.")
        |> redirect(to: ~p"/images/#{duplicate_report.image_id}")

      {:error, _changeset} ->
        report_failed(conn, source)
    end
  end

  defp report_failed(conn, source) do
    conn
    |> put_flash(:error, "Failed to submit duplicate report")
    |> redirect(to: ~p"/images/#{source}")
  end

  defp load_image(id) do
    case PhilomenaWeb.IntegerId.parse(id) do
      {:ok, id} -> Repo.get(Image, id)
      :error -> nil
    end
  end

  def show(conn, _params) do
    dr = conn.assigns.duplicate_report

    render(conn, "show.html",
      title: "Showing Duplicate Report",
      duplicate_report: dr,
      layout_class: "layout--wide"
    )
  end
end
