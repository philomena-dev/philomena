defmodule PhilomenaWeb.Image.Comment.HistoryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Images.Image
  alias Philomena.Comments

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  plug PhilomenaWeb.LoadCommentPlug

  def index(conn, _params) do
    image = conn.assigns.image
    comment = conn.assigns.comment
    renderer = &MarkdownRenderer.render_collection(&1, conn)
    versions = Comments.list_comment_versions(comment, renderer, conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Comment History for comment #{comment.id} on image #{image.id}",
      versions: versions,
      body: renderer.([comment])
    )
  end
end
