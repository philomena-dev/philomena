defmodule Philomena.VersionsTest do
  @moduledoc """
  Tests for `Philomena.Versions.record_edit/4` (exercised through the public
  `Posts.update_post/3` and `Comments.update_comment/3` context functions, as
  it only runs inside their update Multi) and `load_post_versions/1` /
  `load_comment_versions/1`.
  """

  use Philomena.DataCase, async: true

  import Philomena.CommentsFixtures
  import Philomena.ForumsFixtures
  import Philomena.ImagesFixtures
  import Philomena.TopicsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Comments
  alias Philomena.Comments.CommentVersion
  alias Philomena.Posts
  alias Philomena.Posts.PostVersion
  alias Philomena.Versions

  defp post_versions(post) do
    PostVersion
    |> where(post_id: ^post.id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  defp comment_versions(comment) do
    CommentVersion
    |> where(comment_id: ^comment.id)
    |> order_by(asc: :id)
    |> Repo.all()
  end

  describe "record_edit/4 for posts" do
    test "first edit creates the initial row and the edit row" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      editor = confirmed_user_fixture()

      topic =
        topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "Original body"}}})

      [post] = topic.posts

      {:ok, _} =
        Posts.update_post(post, editor, %{"body" => "Edited body", "edit_reason" => "typo fix"})

      assert [initial, edit] = post_versions(post)

      # Initial row: captures the pre-first-edit state, stamped with the item's
      # author and creation time, with no edit reason.
      assert initial.post_id == post.id
      assert initial.user_id == author.id
      assert initial.body == "Original body"
      assert initial.edit_reason == nil
      assert DateTime.compare(initial.created_at, post.created_at) == :eq

      # Edit row: the after-edit snapshot, stamped with the editor.
      assert edit.post_id == post.id
      assert edit.user_id == editor.id
      assert edit.body == "Edited body"
      assert edit.edit_reason == "typo fix"
    end

    test "second edit adds exactly one more row" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      editor = confirmed_user_fixture()

      topic =
        topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "Original body"}}})

      [post] = topic.posts

      {:ok, _} =
        Posts.update_post(post, editor, %{"body" => "Edit one", "edit_reason" => "first"})

      assert length(post_versions(post)) == 2

      # Reusing the same in-memory post is fine: record_edit re-checks the DB
      # for an existing initial row, so the second edit adds only its edit row.
      {:ok, _} =
        Posts.update_post(post, editor, %{"body" => "Edit two", "edit_reason" => "second"})

      assert [_initial, first_edit, second_edit] = post_versions(post)
      assert first_edit.body == "Edit one"
      assert second_edit.body == "Edit two"
      assert second_edit.edit_reason == "second"
    end
  end

  describe "record_edit/4 for comments" do
    test "first edit creates the initial row and the edit row" do
      image = image_fixture()
      author = confirmed_user_fixture()
      editor = confirmed_user_fixture()

      comment = comment_fixture(image, author, %{"body" => "Original comment"})

      {:ok, _} =
        Comments.update_comment(comment, editor, %{
          "body" => "Edited comment",
          "edit_reason" => "clarify"
        })

      assert [initial, edit] = comment_versions(comment)

      assert initial.comment_id == comment.id
      assert initial.user_id == author.id
      assert initial.body == "Original comment"
      assert initial.edit_reason == nil
      assert DateTime.compare(initial.created_at, comment.created_at) == :eq

      assert edit.comment_id == comment.id
      assert edit.user_id == editor.id
      assert edit.body == "Edited comment"
      assert edit.edit_reason == "clarify"
    end
  end

  describe "load_post_versions/1" do
    test "returns display entries newest-first with paired previous bodies" do
      forum = forum_fixture()
      author = confirmed_user_fixture()
      editor = confirmed_user_fixture()

      topic =
        topic_fixture(forum, author, %{"posts" => %{"0" => %{"body" => "v0"}}})

      [post] = topic.posts

      {:ok, _} = Posts.update_post(post, editor, %{"body" => "v1", "edit_reason" => "r1"})
      {:ok, _} = Posts.update_post(post, editor, %{"body" => "v2", "edit_reason" => "r2"})

      # Three rows exist (initial v0, edit v1, edit v2), but the oldest row is
      # only a diff base, so two display entries are returned newest-first.
      assert [entry1, entry2] = Versions.load_post_versions(post)

      assert entry1.body == "v2"
      assert entry1.previous_body == "v1"
      assert entry1.edit_reason == "r2"
      assert entry1.parent.id == post.id

      assert entry2.body == "v1"
      assert entry2.previous_body == "v0"
      assert entry2.edit_reason == "r1"

      # The initial row (body "v0") is never returned as an entry.
      refute Enum.any?(Versions.load_post_versions(post), &(&1.body == "v0"))
    end

    test "returns an empty list for a never-edited post" do
      forum = forum_fixture()
      topic = topic_fixture(forum)
      [post] = topic.posts

      assert Versions.load_post_versions(post) == []
    end
  end
end
