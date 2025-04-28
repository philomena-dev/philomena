defmodule PhilomenaWeb.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentLoader
  alias PhilomenaWeb.MarkdownRenderer
  alias PhilomenaQuery.Search
  alias Philomena.{Comments.Query, Comments.Comment}
  import Ecto.Query

  def index(conn, params) do
    cq = params["cq"] || "created_at.gte:1 week ago"

    params = Map.put(conn.params, "cq", cq)
    conn = Map.put(conn, :params, params)
    user = conn.assigns.current_user

    cq
    |> Query.compile(user: user)
    |> render_index(conn)
  end

  defp render_index({:ok, query}, conn) do
    comments =
      CommentLoader.query(conn, query)
      |> Search.search_records(
        preload(Comment, [:deleted_by, image: [:sources, tags: :aliases], user: [awards: :badge]])
      )

    rendered = MarkdownRenderer.render_collection(comments.entries, conn)

    comments = %{comments | entries: Enum.zip(rendered, comments.entries)}

    render(conn, "index.html", title: "Comments", comments: comments)
  end

  defp render_index({:error, msg}, conn) do
    render(conn, "index.html", title: "Comments", error: msg, comments: [])
  end
end
