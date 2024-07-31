defmodule PhilomenaWeb.Topic.Post.HistoryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.Forums.Forum
  alias Philomena.Posts

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
    renderer = &MarkdownRenderer.render_collection(&1, conn)
    versions = Posts.list_post_versions(post, renderer, conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Post History for Post #{post.id} - #{topic.title} - Forums",
      versions: versions
    )
  end
end
