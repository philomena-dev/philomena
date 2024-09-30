defmodule Philomena.Topics do
  @moduledoc """
  The Topics context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Topics.Topic
  alias Philomena.Forums.Forum
  alias Philomena.Posts
  alias Philomena.Notifications

  use Philomena.Subscriptions,
    on_delete: :clear_topic_notification,
    id_name: :topic_id

  @doc """
  Gets a single topic.

  Raises `Ecto.NoResultsError` if the Topic does not exist.

  ## Examples

      iex> get_topic!(123)
      %Topic{}

      iex> get_topic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_topic!(id), do: Repo.get!(Topic, id)

  @doc """
  Creates a topic.

  ## Examples

      iex> create_topic(%{field: value})
      {:ok, %Topic{}}

      iex> create_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_topic(forum, attribution, attrs \\ %{}) do
    now = DateTime.utc_now(:second)

    topic =
      %Topic{}
      |> Topic.creation_changeset(attrs, forum, attribution)

    Multi.new()
    |> Multi.insert(:topic, topic)
    |> Multi.run(:update_topic, fn repo, %{topic: topic} ->
      {count, nil} =
        Topic
        |> where(id: ^topic.id)
        |> repo.update_all(set: [last_post_id: hd(topic.posts).id, last_replied_to_at: now])

      {:ok, count}
    end)
    |> Multi.run(:update_forum, fn repo, %{topic: topic} ->
      {count, nil} =
        Forum
        |> where(id: ^topic.forum_id)
        |> repo.update_all(
          inc: [post_count: 1, topic_count: 1],
          set: [last_post_id: hd(topic.posts).id]
        )

      {:ok, count}
    end)
    |> Multi.run(:notification, &notify_topic/2)
    |> maybe_subscribe_on(:topic, attribution[:user], :watch_on_new_topic)
    |> Repo.transaction()
    |> case do
      {:ok, %{topic: topic}} = result ->
        Posts.reindex_post(hd(topic.posts))
        Posts.report_non_approved(hd(topic.posts))

        result

      error ->
        error
    end
  end

  defp notify_topic(_repo, %{topic: topic}) do
    Notifications.create_forum_topic_notification(topic.user, topic)
  end

  @doc """
  Updates a topic.

  ## Examples

      iex> update_topic(topic, %{field: new_value})
      {:ok, %Topic{}}

      iex> update_topic(topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_topic(%Topic{} = topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Topic.

  ## Examples

      iex> delete_topic(topic)
      {:ok, %Topic{}}

      iex> delete_topic(topic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_topic(%Topic{} = topic) do
    Repo.delete(topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic changes.

  ## Examples

      iex> change_topic(topic)
      %Ecto.Changeset{source: %Topic{}}

  """
  def change_topic(%Topic{} = topic) do
    Topic.changeset(topic, %{})
  end

  def stick_topic(topic) do
    Topic.stick_changeset(topic)
    |> Repo.update()
  end

  def unstick_topic(topic) do
    Topic.unstick_changeset(topic)
    |> Repo.update()
  end

  def lock_topic(%Topic{} = topic, attrs, user) do
    Topic.lock_changeset(topic, attrs, user)
    |> Repo.update()
  end

  def unlock_topic(%Topic{} = topic) do
    Topic.unlock_changeset(topic)
    |> Repo.update()
  end

  def move_topic(topic, new_forum_id) do
    old_forum_id = topic.forum_id
    topic_changes = Topic.move_changeset(topic, new_forum_id)

    Multi.new()
    |> Multi.update(:topic, topic_changes)
    |> Multi.run(:update_old_forum, fn repo, %{topic: topic} ->
      {count, nil} =
        Forum
        |> where(id: ^old_forum_id)
        |> repo.update_all(inc: [post_count: -topic.post_count, topic_count: -1])

      {:ok, count}
    end)
    |> Multi.run(:update_new_forum, fn repo, %{topic: topic} ->
      {count, nil} =
        Forum
        |> where(id: ^topic.forum_id)
        |> repo.update_all(inc: [post_count: topic.post_count, topic_count: 1])

      {:ok, count}
    end)
    |> Repo.transaction()
  end

  def hide_topic(topic, deletion_reason, user) do
    topic_changes = Topic.hide_changeset(topic, deletion_reason, user)

    forums =
      Forum
      |> join(:inner, [f], _ in assoc(f, :last_post))
      |> where([f, p], p.topic_id == ^topic.id)
      |> update(set: [last_post_id: nil])

    Multi.new()
    |> Multi.update(:topic, topic_changes)
    |> Multi.update_all(:forums, forums, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{topic: topic}} ->
        {:ok, topic}

      error ->
        error
    end
  end

  def unhide_topic(topic) do
    Topic.unhide_changeset(topic)
    |> Repo.update()
  end

  def update_topic_title(topic, attrs) do
    topic
    |> Topic.title_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Removes all topic notifications for a given topic and user.

  ## Examples

      iex> clear_topic_notification(topic, user)
      :ok

  """
  def clear_topic_notification(%Topic{} = topic, user) do
    Notifications.clear_forum_post_notification(topic, user)
    Notifications.clear_forum_topic_notification(topic, user)
    :ok
  end
end
