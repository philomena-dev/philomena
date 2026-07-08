defmodule PhilomenaWeb.TagChange.RevertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # mass_revert reads the tag changes from Postgres and re-tags through
  # Images.batch_update; every reindex is a dead Exq enqueue, so this stays
  # Postgres-only.

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Repo
  alias Philomena.TagChanges.TagChange

  import Ecto.Query

  setup do
    # Valkey rate-limit counters are not rolled back by the SQL sandbox; reset
    # the tag-change limit so accumulated counts don't trip check_limits.
    reset_tag_change_limits()
    :ok
  end

  # Arranges an image whose tags went from "safe" to three tags, returning the
  # image plus the id of the single TagChange row that recorded the two adds.
  defp tag_change!(user) do
    image = image_fixture()

    {:ok, _} =
      Images.update_tags(image, attribution(user), %{
        "old_tag_input" => "safe",
        "tag_input" => "safe, added test tag, other added tag"
      })

    tc = Repo.one!(from tc in TagChange, where: tc.image_id == ^image.id)
    {image, tc}
  end

  defp image_tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
  end

  describe "POST /tag_changes/revert" do
    test "is rejected for anonymous users", %{conn: conn} do
      conn = post(conn, ~p"/tag_changes/revert", %{"ids" => ["1"]})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "is rejected for regular users", %{conn: conn} do
      conn = log_in_user(conn, confirmed_user_fixture())
      conn = post(conn, ~p"/tag_changes/revert", %{"ids" => ["1"]})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
    end

    test "a moderator reverts the listed tag changes", %{conn: conn} do
      author = confirmed_user_fixture()
      {image, tc} = tag_change!(author)

      assert "added test tag" in image_tag_names(image)

      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tag_changes/revert", %{"ids" => ["#{tc.id}"]})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully reverted 1 tag changes"

      # Reverting the change removes the two tags it had added.
      names = image_tag_names(image)
      refute "added test tag" in names
      refute "other added tag" in names
      assert "safe" in names
    end

    test "an empty id list reverts nothing and reports zero", %{conn: conn} do
      # NOTE: the controller reduces over the loaded tag changes, so an empty
      # list is a clean success that reports "0 tag changes".
      conn = log_in_user(conn, moderator_user_fixture())
      conn = post(conn, ~p"/tag_changes/revert", %{"ids" => []})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully reverted 0 tag changes"
    end

    test "a non-list ids param is an action clause error", %{conn: conn} do
      # NOTE: create/2 only matches when "ids" is a list; a scalar value has no
      # matching clause and raises Phoenix.ActionClauseError (500).
      conn = log_in_user(conn, moderator_user_fixture())

      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/tag_changes/revert", %{"ids" => "42"})
      end
    end
  end
end
