defmodule PhilomenaWeb.Image.Comment.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Versions
  alias Philomena.Images.Image
  alias PhilomenaWeb.MarkdownRenderer

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  plug PhilomenaWeb.LoadCommentPlug

  def index(conn, _params) do
    image = conn.assigns.image
    comment = conn.assigns.comment

    versions =
      comment
      |> Versions.load_comment_versions()
      |> MarkdownRenderer.render_version_diffs()

    render(conn, "index.html",
      title: "Comment History for comment #{comment.id} on image #{image.id}",
      versions: versions
    )
  end
end
