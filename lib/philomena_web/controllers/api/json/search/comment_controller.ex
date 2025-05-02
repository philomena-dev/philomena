defmodule PhilomenaWeb.Api.Json.Search.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.CommentLoader
  alias PhilomenaQuery.Search
  alias Philomena.Comments.Comment
  alias Philomena.Comments.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(params["q"], user: user) do
      {:ok, query} ->
        comments =
          CommentLoader.query(conn, query)
          |> Search.search_records(preload(Comment, [:image, :user]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.CommentView)
        |> render("index.json", comments: comments, total: comments.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
