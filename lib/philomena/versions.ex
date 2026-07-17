defmodule Philomena.Versions do
  @moduledoc """
  The Versions context.

  Edit histories for posts and comments. Version rows are after-edit
  snapshots: each row holds the body and edit reason as of one edit, made by
  `user_id` at `created_at`. The state an item had before its first edit
  lives in an initial row stamped with the item's author and creation time,
  created lazily when the item is first edited — never-edited items have no
  version rows at all.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Comments.Comment
  alias Philomena.Comments.CommentVersion
  alias Philomena.Posts.Post
  alias Philomena.Posts.PostVersion

  @doc """
  Returns the most recent versions of a post, prepared for display.

  Each returned version carries `previous_body` from the next-older row and
  `parent` for attribution; the oldest row of an item's history only serves
  as a diff base and is not returned as an entry. Versions are returned
  newest-first, with `user` (and awards) preloaded, at most 25.
  """
  def load_post_versions(post), do: load_versions(PostVersion, :post_id, post)

  @doc """
  Returns the most recent versions of a comment, prepared for display.

  See `load_post_versions/1`.
  """
  def load_comment_versions(comment), do: load_versions(CommentVersion, :comment_id, comment)

  defp load_versions(schema, fk, parent) do
    schema
    |> where([v], field(v, ^fk) == ^parent.id)
    |> order_by(desc: :created_at, desc: :id)
    |> limit(26)
    |> preload(user: [awards: :badge])
    |> Repo.all()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [version, previous] ->
      %{version | parent: parent, previous_body: previous.body}
    end)
  end

  @doc """
  Records an edit of a post or comment, given the item as it was before the
  edit and as it is after.

  Inserts the after-edit version row, preceded by the initial row capturing
  the pre-first-edit state if this is the item's first recorded edit. Must
  run inside the transaction that updated the item: the item's row lock
  serializes concurrent edits, making the first-edit check race-free.

  Returns `{:ok, version}`, shaped for `Ecto.Multi.run/3`.
  """
  def record_edit(repo, %Post{} = original, %Post{} = updated, editor) do
    record_edit(repo, PostVersion, :post_id, original, updated, editor)
  end

  def record_edit(repo, %Comment{} = original, %Comment{} = updated, editor) do
    record_edit(repo, CommentVersion, :comment_id, original, updated, editor)
  end

  defp record_edit(repo, schema, fk, original, updated, editor) do
    unless repo.exists?(where(schema, [v], field(v, ^fk) == ^original.id)) do
      repo.insert!(
        struct(schema, [
          {fk, original.id},
          {:user_id, original.user_id},
          {:body, original.body || ""},
          {:created_at, original.created_at}
        ])
      )
    end

    repo.insert(
      struct(schema, [
        {fk, updated.id},
        {:user_id, editor.id},
        {:body, updated.body || ""},
        {:edit_reason, updated.edit_reason}
      ])
    )
  end
end
