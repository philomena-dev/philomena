defmodule PhilomenaWeb.ReportController do
  use PhilomenaWeb, :controller

  alias Philomena.Reports.Report
  alias Philomena.Reports
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user

    reports =
      Report
      |> where(user_id: ^user.id)
      |> order_by(desc: :created_at)
      |> preload(:rule)
      |> Repo.paginate(conn.assigns.scrivener)

    reports = %{reports | entries: Reports.preload_targets(reports)}

    render(conn, "index.html", title: "My Reports", reports: reports)
  end

  # Make sure that you load the resource in your controller:
  #
  # plug PhilomenaWeb.FilterBannedUsersPlug
  # plug PhilomenaWeb.UserAttributionPlug
  # plug PhilomenaWeb.CaptchaPlug
  # plug PhilomenaWeb.CheckCaptchaPlug when action in [:create]
  # plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, action, subject, target, %{"report" => report_params}) do
    attribution = conn.assigns.attributes

    if too_many_reports?(conn) do
      conn
      |> put_flash(
        :error,
        "You may not have more than #{max_reports()} open reports at a time. Did you read the reporting tips?"
      )
      |> redirect(to: "/")
    else
      case Reports.create_report(attribution, report_params, target) do
        {:ok, _report} ->
          conn
          |> put_flash(
            :info,
            "Your report has been received and will be checked by staff shortly."
          )
          |> redirect(to: redirect_path(conn.assigns.current_user))

        {:error, changeset} ->
          # The calling controllers are thin wrappers with no view of their own,
          # so Phoenix's default view - derived from the caller's name - does
          # not exist. Name the shared one explicitly.
          conn
          |> put_view(PhilomenaWeb.ReportView)
          |> render("new.html", subject: subject, changeset: changeset, action: action)
      end
    end
  end

  defp too_many_reports?(conn) do
    user = conn.assigns.current_user

    case user do
      %{role: role} when role != "user" ->
        false

      _user ->
        too_many_reports_user?(user) or too_many_reports_ip?(conn)
    end
  end

  defp too_many_reports_user?(nil), do: false

  defp too_many_reports_user?(user) do
    reports_open =
      Report
      |> where(user_id: ^user.id)
      |> where([r], r.state in ["open", "in_progress"])
      |> Repo.aggregate(:count, :id)

    reports_open >= max_reports()
  end

  defp too_many_reports_ip?(conn) do
    attribution = conn.assigns.attributes

    reports_open =
      Report
      |> where(ip: ^attribution[:ip])
      |> where([r], r.state in ["open", "in_progress"])
      |> Repo.aggregate(:count, :id)

    reports_open >= max_reports()
  end

  defp redirect_path(nil), do: "/"
  defp redirect_path(_user), do: ~p"/reports"

  defp max_reports do
    5
  end
end
