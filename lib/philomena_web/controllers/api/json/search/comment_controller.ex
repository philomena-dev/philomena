defmodule PhilomenaWeb.Api.Json.Search.CommentController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Search
  alias Philomena.Comments.Comment
  alias Philomena.Comments.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    case Query.compile(params["q"], user: user) do
      {:ok, query} ->
        comments =
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
              sort: %{posted_at: :desc}
            },
            conn.assigns.pagination
          )
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
