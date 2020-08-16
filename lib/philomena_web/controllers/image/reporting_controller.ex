defmodule PhilomenaWeb.Image.ReportingController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DuplicateReports
  alias Philomena.SpoilerExecutor
  alias Philomena.Repo
  import Ecto.Query

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [:tags]

  def show(conn, _params) do
    image = conn.assigns.image

    dupe_reports =
      DuplicateReport
      |> preload([:user, :modifier, image: [:user, :tags], duplicate_of_image: [:user, :tags]])
      |> where([d], d.image_id == ^image.id or d.duplicate_of_image_id == ^image.id)
      |> Repo.all()

    changeset =
      %DuplicateReport{}
      |> DuplicateReports.change_duplicate_report()

    spoilers =
      SpoilerExecutor.execute_spoiler(
        conn.assigns.compiled_spoiler,
        Enum.map(dupe_reports, &[&1.image, &1.duplicate_of_image])
      )

    render(conn, "show.html",
      layout: false,
      image: image,
      dupe_reports: dupe_reports,
      changeset: changeset,
      spoilers: spoilers
    )
  end
end
