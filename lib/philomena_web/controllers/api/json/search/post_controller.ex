defmodule PhilomenaWeb.Api.Json.Search.PostController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Cursor
  alias PhilomenaQuery.Search
  alias Philomena.Posts.Post
  alias Philomena.Posts.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(params["q"], user: user) do
      {:ok, query} ->
        {posts, cursors} =
          Post
          |> Search.search_definition(
            %{
              query: %{
                bool: %{
                  must: [
                    query,
                    %{term: %{deleted: false}},
                    %{term: %{access_level: "normal"}}
                  ]
                }
              },
              sort: [%{created_at: :desc}, %{id: :desc}]
            },
            conn.assigns.pagination
          )
          |> Cursor.search_records(preload(Post, [:user, :topic]), params["search_after"])

        conn
        |> put_view(PhilomenaWeb.Api.Json.Forum.Topic.PostView)
        |> render("index.json", cursors: cursors, posts: posts, total: posts.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end
end
