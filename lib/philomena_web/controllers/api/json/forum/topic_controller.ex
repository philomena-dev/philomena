defmodule PhilomenaWeb.Api.Json.Forum.TopicController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias PhilomenaQuery.Cursor
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{"forum_id" => id} = params) do
    {topics, cursors} =
      Topic
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where(hidden_from_users: false)
      |> where([_t, f], f.access_level == "normal" and f.short_name == ^id)
      |> preload([:user])
      |> Cursor.paginate(conn.assigns.scrivener, params["search_after"],
        desc: :sticky,
        desc: :last_replied_to_at,
        desc: :slug
      )

    render(conn, "index.json", cursors: cursors, topics: topics, total: topics.total_entries)
  end

  def show(conn, %{"forum_id" => forum_id, "id" => id}) do
    topic =
      Topic
      |> join(:inner, [t], _ in assoc(t, :forum))
      |> where(slug: ^id)
      |> where(hidden_from_users: false)
      |> where([_t, f], f.access_level == "normal" and f.short_name == ^forum_id)
      |> preload([:user])
      |> Repo.one()

    cond do
      is_nil(topic) ->
        conn
        |> put_status(:not_found)
        |> text("")

      true ->
        render(conn, "show.json", topic: topic)
    end
  end
end
