defmodule PhilomenaWeb.Api.Json.Forum.Topic.PostController do
  use PhilomenaWeb, :controller

  alias Philomena.Topics.Topic
  alias Philomena.Posts.Post
  alias PhilomenaWeb.IntegerId
  alias Philomena.Repo
  import Ecto.Query
  import PhilomenaWeb.Api.Json.NotFound

  def index(conn, %{"forum_id" => forum_id, "topic_id" => topic_id}) do
    case load_topic(forum_id, topic_id) do
      nil ->
        not_found(conn)

      topic ->
        %{page_number: page, page_size: page_size} = conn.assigns.pagination

        posts =
          Post
          |> where(topic_id: ^topic.id)
          |> where(destroyed_content: false)
          |> where(
            [p],
            p.topic_position >= ^(page_size * (page - 1)) and
              p.topic_position < ^(page_size * page)
          )
          |> order_by(asc: :topic_position)
          |> preload(:user)
          |> Repo.all()
          |> Enum.map(&%{&1 | topic: topic})

        render(conn, "index.json", posts: posts, total: topic.post_count)
    end
  end

  def show(conn, %{"forum_id" => forum_id, "topic_id" => topic_id, "id" => post_id}) do
    case IntegerId.parse(post_id) do
      {:ok, post_id} -> show_post(conn, forum_id, topic_id, post_id)
      :error -> not_found(conn)
    end
  end

  defp show_post(conn, forum_id, topic_id, post_id) do
    post =
      Post
      |> join(:inner, [p], _ in assoc(p, :topic))
      |> join(:inner, [_p, t], _ in assoc(t, :forum))
      |> where(id: ^post_id)
      |> where(destroyed_content: false)
      |> where([_p, t], t.hidden_from_users == false and t.slug == ^topic_id)
      |> where([_p, _t, f], f.access_level == "normal" and f.short_name == ^forum_id)
      |> preload([:user, :topic])
      |> Repo.one()

    if is_nil(post) do
      not_found(conn)
    else
      render(conn, "show.json", post: post)
    end
  end

  defp load_topic(forum_id, topic_id) do
    Topic
    |> join(:inner, [t], _ in assoc(t, :forum))
    |> where([t], t.hidden_from_users == false and t.slug == ^topic_id)
    |> where([_t, f], f.access_level == "normal" and f.short_name == ^forum_id)
    |> Repo.one()
  end
end
