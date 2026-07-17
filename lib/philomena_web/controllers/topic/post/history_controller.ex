defmodule PhilomenaWeb.Topic.Post.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.Versions
  alias Philomena.Forums.Forum
  alias PhilomenaWeb.MarkdownRenderer

  plug PhilomenaWeb.CanaryMapPlug, index: :show

  plug :load_and_authorize_resource,
    model: Forum,
    id_name: "forum_id",
    id_field: "short_name",
    persisted: true

  plug PhilomenaWeb.LoadTopicPlug
  plug PhilomenaWeb.LoadPostPlug

  def index(conn, _params) do
    topic = conn.assigns.topic
    post = conn.assigns.post

    versions =
      post
      |> Versions.load_post_versions()
      |> MarkdownRenderer.render_version_diffs()

    render(conn, "index.html",
      title: "Post History for Post #{post.id} - #{topic.title} - Forums",
      versions: versions
    )
  end
end
