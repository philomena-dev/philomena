defmodule Philomena.Topics do
  @moduledoc """
  The Topics context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Topics.Topic
  alias Philomena.Forums
  alias Philomena.Forums.Forum
  alias Philomena.Posts
  alias Philomena.UserStatistics
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
        UserStatistics.inc_stat(topic.user, :topics)
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

  @doc """
  Makes a topic sticky, appearing at the top of its forum.

  ## Examples

      iex> stick_topic(topic)
      {:ok, %Topic{}}

  """
  def stick_topic(topic) do
    Topic.stick_changeset(topic)
    |> Repo.update()
  end

  @doc """
  Removes sticky status from a topic.

  ## Examples

      iex> unstick_topic(topic)
      {:ok, %Topic{}}

  """
  def unstick_topic(topic) do
    Topic.unstick_changeset(topic)
    |> Repo.update()
  end

  @doc """
  Locks a topic to prevent further posting.

  ## Examples

      iex> lock_topic(topic, %{"lock_reason" => "Off topic"}, user)
      {:ok, %Topic{}}

  """
  def lock_topic(%Topic{} = topic, attrs, user) do
    Topic.lock_changeset(topic, attrs, user)
    |> Repo.update()
  end

  @doc """
  Unlocks a topic to allow posting again.

  ## Examples

      iex> unlock_topic(topic)
      {:ok, %Topic{}}

  """
  def unlock_topic(%Topic{} = topic) do
    Topic.unlock_changeset(topic)
    |> Repo.update()
  end

  @doc """
  Moves a topic to a different forum, updating post counts for both forums.

  ## Examples

      iex> move_topic(topic, 123)
      {:ok, %{topic: %Topic{}}}

  """
  def move_topic(topic, new_forum_id) do
    old_forum_id = topic.forum_id

    Multi.new()
    |> Multi.update(:topic, Topic.move_changeset(topic, new_forum_id))
    |> Multi.update_all(
      :old_forum,
      Forums.update_forum_last_post_query(old_forum_id),
      inc: [post_count: -topic.post_count, topic_count: -1]
    )
    |> Multi.update_all(
      :new_forum,
      Forums.update_forum_last_post_query(new_forum_id),
      inc: [post_count: topic.post_count, topic_count: 1]
    )
    |> Repo.transaction()
  end

  @doc """
  Hides a topic and updates related forum data.

  ## Examples

      iex> hide_topic(topic, "Violates rules", moderator)
      {:ok, %Topic{}}

  """
  def hide_topic(topic, deletion_reason, user) do
    topic = topic |> Repo.preload(:user)

    Multi.new()
    |> Multi.update(:topic, Topic.hide_changeset(topic, deletion_reason, user))
    |> Multi.update_all(
      :forum,
      Forums.update_forum_last_post_query(topic.forum_id),
      inc: [post_count: -topic.post_count, topic_count: -1]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{topic: topic}} ->
        UserStatistics.inc_stat(topic.user, :topics, -1)

        {:ok, topic}

      error ->
        error
    end
  end

  @doc """
  Unhides a previously hidden topic.

  ## Examples

      iex> unhide_topic(topic)
      {:ok, %Topic{}}

  """
  def unhide_topic(topic) do
    topic = topic |> Repo.preload(:user)

    Multi.new()
    |> Multi.update(:topic, Topic.unhide_changeset(topic))
    |> Multi.update_all(
      :forum,
      Forums.update_forum_last_post_query(topic.forum_id),
      inc: [post_count: topic.post_count, topic_count: 1]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{topic: topic}} ->
        UserStatistics.inc_stat(topic.user, :topics)

        {:ok, topic}

      error ->
        error
    end
  end

  @doc """
  Updates a topic's title.

  ## Examples

      iex> update_topic_title(topic, %{"title" => "New Title"})
      {:ok, %Topic{}}

  """
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

  @doc """
  Returns an `m:Ecto.Query` which updates the last post for the given topic.

  ## Examples

      iex> update_topic_last_post_query(1)
      #Ecto.Query<...>

  """
  def update_topic_last_post_query(topic_id) do
    Topic
    |> where(id: ^topic_id)
    |> update(
      set: [
        last_post_id:
          fragment(
            "SELECT max(id) FROM posts WHERE topic_id = ? AND hidden_from_users IS FALSE",
            ^topic_id
          )
      ]
    )
  end
end
