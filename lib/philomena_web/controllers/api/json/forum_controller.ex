defmodule PhilomenaWeb.Api.Json.ForumController do
  use PhilomenaWeb, :controller

  alias PhilomenaQuery.Cursor
  alias Philomena.Forums.Forum
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, params) do
    {forums, cursors} =
      Forum
      |> where(access_level: "normal")
      |> Cursor.paginate(conn.assigns.scrivener, params["search_after"],
        asc: :name,
        asc: :short_name
      )

    render(conn, cursors: cursors, forums: forums, total: forums.total_entries)
  end

  def show(conn, %{"id" => id}) do
    forum =
      Forum
      |> where(short_name: ^id)
      |> where(access_level: "normal")
      |> Repo.one()

    cond do
      is_nil(forum) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        render(conn, forum: forum)
    end
  end
end
