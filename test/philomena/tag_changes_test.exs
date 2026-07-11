defmodule Philomena.TagChangesTest do
  @moduledoc """
  Context-level tests for the actor-first `Philomena.TagChanges` API:
  `delete_tag_change/2`, `revert_tag_changes/2`, and `full_revert/2`.

  These pin the authorization matrix (anonymous/user/moderator/admin), the
  two global error shapes, and the moderation log entries - type strings,
  bodies, and subject paths byte-for-byte - that each function writes on
  success. The corresponding controller characterization tests pin the HTTP
  behavior on top of these results.
  """

  use Philomena.DataCase, async: false

  # delete_tag_change/2 removes the record's search document, so this module
  # follows the OpenSearch test rules (async: false, index cycled in setup).
  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  import Ecto.Query

  alias Philomena.Images
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.ModerationLogs.Paths
  alias Philomena.Repo
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias PhilomenaQuery.Search

  setup do
    Search.clear_index!(TagChange)
    # Valkey rate-limit counters are not rolled back by the SQL sandbox; reset
    # the tag-change limit so accumulated counts don't trip check_limits.
    reset_tag_change_limits()
    :ok
  end

  # Arranges an image whose tags went from "safe" to three tags, returning the
  # image plus the single TagChange row that recorded the two adds.
  defp tag_change!(user) do
    image = image_fixture()

    {:ok, _} =
      Images.update_tags(image, attribution(user), %{
        "old_tag_input" => "safe",
        "tag_input" => "safe, added test tag, other added tag"
      })

    {image, Repo.one!(from tc in TagChange, where: tc.image_id == ^image.id)}
  end

  defp image_tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
  end

  defp only_moderation_log! do
    Repo.one!(ModerationLog)
  end

  describe "delete_tag_change/2" do
    test "denies an anonymous actor" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert TagChanges.delete_tag_change(nil, "#{tc.id}") == {:error, :unauthorized}
      assert Repo.get(TagChange, tc.id)
    end

    test "denies a regular user" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert TagChanges.delete_tag_change(confirmed_user_fixture(), "#{tc.id}") ==
               {:error, :unauthorized}

      assert Repo.get(TagChange, tc.id)
    end

    test "a moderator deletes the change and a moderation log is written" do
      author = confirmed_user_fixture()
      moderator = moderator_user_fixture()
      {image, tc} = tag_change!(author)

      assert {:ok, %TagChange{}} = TagChanges.delete_tag_change(moderator, "#{tc.id}")
      refute Repo.get(TagChange, tc.id)

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange:delete"
      assert log.subject_path == "/images/#{image.id}"

      assert log.body ==
               "Deleted tag change by #{author.name} containing 2 tags on image #{image.id} from history"
    end

    test "an admin may also delete" do
      {_image, tc} = tag_change!(confirmed_user_fixture())

      assert {:ok, %TagChange{}} = TagChanges.delete_tag_change(admin_user_fixture(), tc.id)
    end

    test "deleting an anonymous change logs the author as anonymous" do
      moderator = moderator_user_fixture()
      {image, tc} = tag_change!(nil)

      assert {:ok, %TagChange{}} = TagChanges.delete_tag_change(moderator, "#{tc.id}")
      refute Repo.get(TagChange, tc.id)

      assert only_moderation_log!().body ==
               "Deleted tag change by 203.0.113.1 containing 2 tags on image #{image.id} from history"
    end

    test "a well-formed id naming no row is unauthorized, not not-found" do
      # The former load-then-authorize plug authorized the nil load result,
      # which no :delete rule permits; the context preserves that shape.
      assert TagChanges.delete_tag_change(moderator_user_fixture(), "123456789") ==
               {:error, :unauthorized}
    end

    test "an id that cannot name a row is not found" do
      moderator = moderator_user_fixture()

      assert TagChanges.delete_tag_change(moderator, "not-an-integer") == {:error, :not_found}

      assert TagChanges.delete_tag_change(moderator, "99999999999999999999") ==
               {:error, :not_found}
    end
  end

  describe "revert_tag_changes/2" do
    test "denies an anonymous actor" do
      assert TagChanges.revert_tag_changes(actor(), ["1"]) == {:error, :unauthorized}
    end

    test "denies a regular user before looking at the ids" do
      # Authorization comes first, as it did when it was a plug: a bad ids
      # shape from an unprivileged user is still unauthorized.
      user_actor = actor(confirmed_user_fixture())

      assert TagChanges.revert_tag_changes(user_actor, ["1"]) == {:error, :unauthorized}
      assert TagChanges.revert_tag_changes(user_actor, "42") == {:error, :unauthorized}
    end

    test "a moderator reverts the listed changes and a moderation log is written" do
      moderator = moderator_user_fixture()
      {image, tc} = tag_change!(confirmed_user_fixture())

      assert "added test tag" in image_tag_names(image)

      assert {:ok, [%TagChange{}]} =
               TagChanges.revert_tag_changes(actor(moderator), ["#{tc.id}"])

      # Reverting the change removes the two tags it had added.
      names = image_tag_names(image)
      refute "added test tag" in names
      refute "other added tag" in names
      assert "safe" in names

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange.Revert:create"
      # Slug encoding (e.g. `@` → `%40`) is pinned in the Paths tests.
      assert log.subject_path == Paths.profile_path(moderator)
      assert log.body == "Reverted 1 tag changes"
    end

    test "an empty list is a successful reversion of zero changes" do
      assert {:ok, []} = TagChanges.revert_tag_changes(actor(moderator_user_fixture()), [])

      assert only_moderation_log!().body == "Reverted 0 tag changes"
    end

    test "a non-list ids value from a moderator is invalid" do
      assert TagChanges.revert_tag_changes(actor(moderator_user_fixture()), "42") ==
               {:error, :invalid_ids}

      assert Repo.aggregate(ModerationLog, :count) == 0
    end
  end

  describe "full_revert/2" do
    test "denies an anonymous actor" do
      assert TagChanges.full_revert(actor(), %{"user_id" => "1"}) == {:error, :unauthorized}
    end

    test "denies a regular user before looking at the target" do
      user_actor = actor(confirmed_user_fixture())

      assert TagChanges.full_revert(user_actor, %{"user_id" => "1"}) == {:error, :unauthorized}

      assert TagChanges.full_revert(user_actor, %{"something" => "else"}) ==
               {:error, :unauthorized}
    end

    test "a moderator enqueues a reversion for a user and the log names them" do
      moderator = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert TagChanges.full_revert(actor(moderator), %{"user_id" => "#{target.id}"}) ==
               {:ok, %{user_id: "#{target.id}"}}

      log = only_moderation_log!()
      assert log.user_id == moderator.id
      assert log.type == "TagChange.FullRevert:create"
      assert log.subject_path == Paths.profile_path(target)
      assert log.body == "Reverted all tag changes for user #{target.name}"
    end

    test "a user id naming no user still logs, against the tag changes listing" do
      assert {:ok, _target} =
               TagChanges.full_revert(actor(moderator_user_fixture()), %{
                 "user_id" => "123456789"
               })

      log = only_moderation_log!()
      assert log.subject_path == "/tag_changes"
      assert log.body == "Reverted all tag changes for user 123456789"
    end

    test "a moderator enqueues a reversion for an ip" do
      assert {:ok, %{ip: "203.0.113.9"}} =
               TagChanges.full_revert(actor(moderator_user_fixture()), %{"ip" => "203.0.113.9"})

      log = only_moderation_log!()
      assert log.type == "TagChange.FullRevert:create"
      assert log.subject_path == "/ip_profiles/203.0.113.9"
      assert log.body == "Reverted all tag changes for ip 203.0.113.9"
    end

    test "a moderator enqueues a reversion for a fingerprint" do
      assert {:ok, %{fingerprint: "c1774e9294a"}} =
               TagChanges.full_revert(actor(moderator_user_fixture()), %{
                 "fingerprint" => "c1774e9294a"
               })

      log = only_moderation_log!()
      assert log.subject_path == "/fingerprint_profiles/c1774e9294a"
      assert log.body == "Reverted all tag changes for fingerprint c1774e9294a"
    end

    test "params naming no target are invalid" do
      assert TagChanges.full_revert(actor(moderator_user_fixture()), %{"something" => "else"}) ==
               {:error, :invalid_target}

      assert Repo.aggregate(ModerationLog, :count) == 0
    end
  end
end
