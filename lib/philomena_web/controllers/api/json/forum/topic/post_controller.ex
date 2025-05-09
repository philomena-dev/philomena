defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias PhilomenaQuery.Cursor
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, %{
        "forum_id" => forum_id,
        "topic_id" => topic_id,
        "search_after" => search_after
      }) do
    topic = Repo.one!(topic_query(topic_id, forum_id))

    {posts, cursors} =
      post_query(topic_id, forum_id)
      |> Cursor.paginate(conn.assigns.scrivener, search_after, asc: :topic_position)

    render(conn, "index.json", cursors: cursors, posts: posts, total: topic.post_count)
  end

  def index(conn, %{"forum_id" => forum_id, "topic_id" => topic_id}) do
    page = conn.assigns.pagination.page_number

    topic = Repo.one!(topic_query(topic_id, forum_id))

    {posts, cursors} =
      post_query(topic_id, forum_id)
      |> where(
        [posts: p],
        p.topic_position >= ^(25 * (page - 1)) and p.topic_position < ^(25 * page)
      )
      |> Cursor.paginate([page_size: 25], [], asc: :topic_position)

    render(conn, "index.json", cursors: cursors, posts: posts, total: topic.post_count)
  end

  def show(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => post_id}) do
    post =
      post_query(forum_id, topic_id)
      |> where(id: ^post_id)
      |> Repo.one()

    if is_nil(post) do
      conn
      |> put_status(:not_found)
      |> text("")
    else
      render(conn, "show.json", post: post)
    end
  end

  defp topic_query(topic_id, forum_id) do
    Topic
    |> from(as: :topic)
    |> join(:inner, [topic: t], _ in assoc(t, :forum), as: :forum)
    |> topic_conditions(topic_id, forum_id)
  end

  defp post_query(topic_id, forum_id) do
    Post
    |> from(as: :posts)
    |> join(:inner, [posts: p], _ in assoc(p, :topic), as: :topic)
    |> join(:inner, [topic: t], _ in assoc(t, :forum), as: :forum)
    |> topic_conditions(topic_id, forum_id)
    |> where([posts: p], p.destroyed_content == false)
    |> preload([:user])
  end

  defp topic_conditions(queryable, topic_id, forum_id) do
    queryable
    |> where([topic: t], t.hidden_from_users == false and t.slug == ^topic_id)
    |> where([forum: f], f.access_level == "normal" and f.short_name == ^forum_id)
  end
end
