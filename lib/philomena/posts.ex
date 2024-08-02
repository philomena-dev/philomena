defmodule Philomena.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.Topics.Topic
  alias Philomena.Topics
  alias Philomena.UserStatistics
  alias Philomena.Posts.Post
  alias Philomena.Posts.Version
  alias Philomena.Posts.SearchIndex, as: PostIndex
  alias Philomena.IndexWorker
  alias Philomena.Forums.Forum
  alias Philomena.Notifications
  alias Philomena.NotificationWorker
  alias Philomena.Reports

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(topic, attributes, params \\ %{}) do
    now = DateTime.utc_now(:second)

    topic_query =
      Topic
      |> where(id: ^topic.id)

    topic_lock_query =
      topic_query
      |> lock("FOR UPDATE")

    forum_query =
      Forum
      |> where(id: ^topic.forum_id)

    Multi.new()
    |> Multi.one(:topic, topic_lock_query)
    |> Multi.run(:post, fn repo, _ ->
      last_position =
        Post
        |> where(topic_id: ^topic.id)
        |> order_by(desc: :topic_position)
        |> select([p], p.topic_position)
        |> limit(1)
        |> repo.one()

      Ecto.build_assoc(topic, :posts, [topic_position: (last_position || -1) + 1] ++ attributes)
      |> Post.creation_changeset(params, attributes)
      |> repo.insert()
    end)
    |> Multi.run(:update_topic, fn repo, %{post: %{id: post_id}} ->
      {count, nil} =
        repo.update_all(topic_query,
          inc: [post_count: 1],
          set: [last_post_id: post_id, last_replied_to_at: now]
        )

      {:ok, count}
    end)
    |> Multi.run(:update_forum, fn repo, %{post: %{id: post_id}} ->
      {count, nil} =
        repo.update_all(forum_query, inc: [post_count: 1], set: [last_post_id: post_id])

      {:ok, count}
    end)
    |> Topics.maybe_subscribe_on(:topic, attributes[:user], :watch_on_reply)
    |> Repo.transaction()
    |> case do
      {:ok, %{post: post}} = result ->
        reindex_post(post)

        result

      error ->
        error
    end
  end

  def notify_post(post) do
    Exq.enqueue(Exq, "notifications", NotificationWorker, ["Posts", post.id])
  end

  def report_non_approved(%Post{approved: true}), do: false

  def report_non_approved(post) do
    Reports.create_system_report(
      {"Post", post.id},
      "Approval",
      "Post contains externally-embedded images and has been flagged for review."
    )
  end

  def perform_notify(post_id) do
    post =
      post_id
      |> get_post!()
      |> Repo.preload([:user, :topic])

    Notifications.create_forum_post_notification(post.user, post.topic, post)
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, editor, attrs) do
    version_changeset =
      Version.changeset(%Version{}, post, editor, %{
        body: post.body,
        edit_reason: post.edit_reason,
        created_at: post.edited_at || post.created_at
      })

    now = DateTime.utc_now(:second)
    post_changeset = Post.changeset(post, attrs, now)

    Multi.new()
    |> Multi.insert(:version, version_changeset)
    |> Multi.update(:post, post_changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{post: post}} ->
        if not post.approved do
          report_non_approved(post)
        end

        reindex_post(post)

        {:ok, post}

      _ ->
        {:error, post_changeset}
    end
  end

  def list_post_versions(%Post{} = post, collection_renderer, pagination) do
    versions =
      Version
      |> where(post_id: ^post.id)
      |> order_by(desc: :created_at, desc: :id)
      |> Repo.paginate(pagination)

    bodies = collection_renderer.(versions)
    put_in(versions.entries, Enum.zip(versions, bodies))
  end

  @doc """
  Deletes a Post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  def hide_post(%Post{} = post, attrs, user) do
    report_query = Reports.close_report_query({"Post", post.id}, user)

    topics =
      Topic
      |> where(last_post_id: ^post.id)
      |> update(set: [last_post_id: nil])

    forums =
      Forum
      |> where(last_post_id: ^post.id)
      |> update(set: [last_post_id: nil])

    post = Post.hide_changeset(post, attrs, user)

    Multi.new()
    |> Multi.update(:post, post)
    |> Multi.update_all(:reports, report_query, [])
    |> Multi.update_all(:topics, topics, [])
    |> Multi.update_all(:forums, forums, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{post: post, reports: {_count, reports}}} ->
        Reports.reindex_reports(reports)
        reindex_post(post)

        {:ok, post}

      error ->
        error
    end
  end

  def unhide_post(%Post{} = post) do
    post
    |> Post.unhide_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  def destroy_post(%Post{} = post) do
    post
    |> Post.destroy_changeset()
    |> Repo.update()
    |> reindex_after_update()
  end

  def approve_post(%Post{} = post, user) do
    report_query = Reports.close_report_query({"Post", post.id}, user)
    post = Post.approve_changeset(post)

    Multi.new()
    |> Multi.update(:post, post)
    |> Multi.update_all(:reports, report_query, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{post: post, reports: {_count, reports}}} ->
        notify_post(post)
        UserStatistics.inc_stat(post.user, :forum_posts)
        Reports.reindex_reports(reports)
        reindex_post(post)

        {:ok, post}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{source: %Post{}}

  """
  def change_post(%Post{} = post) do
    Post.changeset(post, %{})
  end

  def user_name_reindex(old_name, new_name) do
    data = PostIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Post, data.query, data.set_replacements, data.replacements)
  end

  defp reindex_after_update({:ok, post}) do
    reindex_post(post)

    {:ok, post}
  end

  defp reindex_after_update(result) do
    result
  end

  def reindex_post(%Post{} = post) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Posts", "id", [post.id]])

    post
  end

  def indexing_preloads do
    [:user, topic: :forum]
  end

  def perform_reindex(column, condition) do
    Post
    |> preload(^indexing_preloads())
    |> where([p], field(p, ^column) in ^condition)
    |> Search.reindex(Post)
  end
end
