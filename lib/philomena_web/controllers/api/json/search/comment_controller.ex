defmodule PhilomenaWeb.Api.Json.Search.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Cursor
  alias PhilomenaQuery.Search
  alias Philomena.Comments.Comment
  alias Philomena.Comments.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    case Query.compile(params["q"], user: user) do
      {:ok, query} ->
        {comments, cursors} =
          Comment
          |> Search.search_definition(
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{term: %{hidden_from_users: false}}
                  ],
                  must_not: %{
                    terms: %{image_tag_ids: filter.hidden_tag_ids}
                  }
                }
              },
              sort: [%{posted_at: :desc}, %{id: :desc}]
            },
            conn.assigns.pagination
          )
          |> Cursor.search_records(preload(Comment, [:image, :user]), params["search_after"])

        conn
        |> put_view(PhilomenaWeb.Api.Json.CommentView)
        |> render("index.json",
          comments: comments,
          cursors: cursors,
          total: comments.total_entries
        )

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
