defmodule Philomena.Comments do
  @moduledoc """
  The Comments context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias PhilomenaQuery.Search
  alias Philomena.UserStatistics
  alias Philomena.Comments.Comment
  alias Philomena.Comments.SearchIndex, as: CommentIndex
  alias Philomena.IndexWorker
  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Notifications
  alias Philomena.Versions
  alias Philomena.Reports

  @doc """
  Gets a single comment.

  Raises `Ecto.NoResultsError` if the Comment does not exist.

  ## Examples

      iex> get_comment!(123)
      %Comment{}

      iex> get_comment!(456)
      ** (Ecto.NoResultsError)

  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{field: value})
      {:ok, %Comment{}}

      iex> create_comment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_comment(image, attribution, params \\ %{}) do
    comment =
      Ecto.build_assoc(image, :comments)
      |> Comment.creation_changeset(params, attribution)

    image_query =
      Image
      |> where(id: ^image.id)

    image_lock_query =
      lock(image_query, "FOR UPDATE")

    Multi.new()
    |> Multi.one(:image, image_lock_query)
    |> Multi.insert(:comment, comment)
    |> Multi.update_all(:update_image, image_query, inc: [comments_count: 1])
    |> Multi.run(:notification, &notify_comment/2)
    |> Images.maybe_subscribe_on(:image, attribution[:user], :watch_on_reply)
    |> Repo.transaction()
  end

  defp notify_comment(_repo, %{image: image, comment: comment}) do
    Notifications.create_image_comment_notification(comment.user, image, comment)
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(comment, %{field: new_value})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_comment(%Comment{} = comment, editor, attrs) do
    now = DateTime.utc_now(:second)
    current_body = comment.body
    current_reason = comment.edit_reason

    comment_changes = Comment.changeset(comment, attrs, now)

    Multi.new()
    |> Multi.update(:comment, comment_changes)
    |> Multi.run(:version, fn _repo, _changes ->
      Versions.create_version("Comment", comment.id, editor.id, %{
        "body" => current_body,
        "edit_reason" => current_reason
      })
    end)
    |> Repo.transaction()
  end

  @doc """
  Deletes a Comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

      iex> delete_comment(comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  def hide_comment(%Comment{} = comment, attrs, user) do
    report_query = Reports.close_report_query({"Comment", comment.id}, user)
    comment = Comment.hide_changeset(comment, attrs, user)

    Multi.new()
    |> Multi.update(:comment, comment)
    |> Multi.update_all(:reports, report_query, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment, reports: {_count, reports}}} ->
        Reports.reindex_reports(reports)
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  def unhide_comment(%Comment{} = comment) do
    comment
    |> Comment.unhide_changeset()
    |> Repo.update()
    |> case do
      {:ok, comment} ->
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  def destroy_comment(%Comment{} = comment) do
    comment
    |> Comment.destroy_changeset()
    |> Repo.update()
  end

  def approve_comment(%Comment{} = comment, user) do
    report_query = Reports.close_report_query({"Comment", comment.id}, user)
    comment = Comment.approve_changeset(comment)

    Multi.new()
    |> Multi.update(:comment, comment)
    |> Multi.update_all(:reports, report_query, [])
    |> Repo.transaction()
    |> case do
      {:ok, %{comment: comment, reports: {_count, reports}}} ->
        UserStatistics.inc_stat(comment.user, :comments_posted)
        Reports.reindex_reports(reports)
        reindex_comment(comment)

        {:ok, comment}

      error ->
        error
    end
  end

  def report_non_approved(%Comment{approved: true}), do: false

  def report_non_approved(comment) do
    Reports.create_system_report(
      {"Comment", comment.id},
      "Approval",
      "Comment contains externally-embedded images and has been flagged for review."
    )
  end

  def migrate_comments(image, duplicate_of_image) do
    {count, nil} =
      Comment
      |> where(image_id: ^image.id)
      |> Repo.update_all(set: [image_id: duplicate_of_image.id])

    Image
    |> where(id: ^duplicate_of_image.id)
    |> Repo.update_all(inc: [comments_count: count])

    reindex_comments(duplicate_of_image)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Ecto.Changeset{source: %Comment{}}

  """
  def change_comment(%Comment{} = comment) do
    Comment.changeset(comment, %{})
  end

  def user_name_reindex(old_name, new_name) do
    data = CommentIndex.user_name_update_by_query(old_name, new_name)

    Search.update_by_query(Comment, data.query, data.set_replacements, data.replacements)
  end

  def reindex_comment(%Comment{} = comment) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "id", [comment.id]])

    comment
  end

  def reindex_comments(image) do
    Exq.enqueue(Exq, "indexing", IndexWorker, ["Comments", "image_id", [image.id]])

    image
  end

  def indexing_preloads do
    [:user, image: :tags]
  end

  def perform_reindex(column, condition) do
    Comment
    |> preload(^indexing_preloads())
    |> where([c], field(c, ^column) in ^condition)
    |> Search.reindex(Comment)
  end
end
