defmodule PhilomenaWeb.Admin.ReportView do
  use PhilomenaWeb, :view

  alias Philomena.Images.Image
  alias Philomena.Comments.Comment

  alias PhilomenaWeb.ReportView
  alias PhilomenaWeb.ProfileView

  defp link_to_reported_thing(reportable),
    do: ReportView.link_to_reported_thing(reportable)

  defp report_row_class(report),
    do: ReportView.report_row_class(report)

  defp pretty_state(report),
    do: ReportView.pretty_state(report)

  defp user_abbrv(user),
    do: ProfileView.user_abbrv(user)

  defp current?(current_user, user),
    do: ProfileView.current?(current_user, user)

  def truncate(<<string::binary-size(50), _rest::binary>>), do: string <> "..."
  def truncate(string), do: string

  def truncated_ip_link(ip) do
    case to_string(ip) do
      <<string::binary-size(25), _rest::binary>> = ip ->
        link(string <> "...", to: ~p"/ip_profiles/#{ip}")

      ip ->
        link(ip, to: ~p"/ip_profiles/#{ip}")
    end
  end

  def ordered_tags(tags) do
    Enum.sort_by(tags, & &1.name)
  end

  def reported_image(conn, %Image{} = image) do
    render(PhilomenaWeb.ImageView, "_image_container.html",
      image: image,
      size: :thumb_tiny,
      conn: conn
    )
  end

  def reported_image(conn, %Comment{image: image}) do
    render(PhilomenaWeb.ImageView, "_image_container.html",
      image: image,
      size: :thumb_tiny,
      conn: conn
    )
  end

  def reported_image(_conn, _reportable), do: nil
end
