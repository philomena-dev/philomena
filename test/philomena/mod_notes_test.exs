defmodule Philomena.ModNotesTest do
  use Philomena.DataCase, async: true

  alias Philomena.ModNotes
  alias Philomena.ModNotes.ModNote
  alias Philomena.Repo

  import Philomena.UsersFixtures
  import Philomena.ReportsFixtures
  import Philomena.ImagesFixtures
  import Philomena.DnpEntriesFixtures
  import Philomena.TagsFixtures

  describe "create_mod_note/3 against a target column" do
    test "a user_id note sets user_id" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()

      {:ok, note} =
        ModNotes.create_mod_note(author, %{"body" => "watching"}, user_id: target.id)

      assert note.user_id == target.id
      assert note.report_id == nil
      assert note.dnp_entry_id == nil
    end

    test "a report_id note sets report_id" do
      author = moderator_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      {:ok, note} =
        ModNotes.create_mod_note(author, %{"body" => "watching report"}, report_id: report.id)

      assert note.report_id == report.id
      assert note.user_id == nil
    end

    test "a dnp_entry_id note sets dnp_entry_id" do
      author = moderator_user_fixture()
      requester = confirmed_user_fixture()
      tag = tag_fixture()
      dnp_entry = dnp_entry_fixture(requester, tag)

      {:ok, note} =
        ModNotes.create_mod_note(author, %{"body" => "watching dnp"}, dnp_entry_id: dnp_entry.id)

      assert note.dnp_entry_id == dnp_entry.id
      assert note.user_id == nil
    end
  end

  describe "create_mod_note/3 validation" do
    test "rejects a note with no target" do
      author = moderator_user_fixture()

      assert {:error, changeset} =
               ModNotes.create_mod_note(author, %{"body" => "orphan attempt"}, [])

      assert errors_on(changeset)[:target] == ["must reference exactly one target"]
    end

    test "rejects a note referencing two targets" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert {:error, changeset} =
               ModNotes.create_mod_note(author, %{"body" => "two targets"},
                 user_id: target.id,
                 report_id: report.id
               )

      assert errors_on(changeset)[:target] == ["must reference exactly one target"]
    end
  end

  describe "orphaned mod note and DB constraint" do
    setup do
      author = moderator_user_fixture()

      {:ok, orphan} =
        %ModNote{moderator_id: author.id}
        |> Ecto.Changeset.change(%{body: "orphan"})
        |> Repo.insert()

      %{orphan: orphan}
    end

    test "all target columns are nil on an all-NULL note", %{orphan: orphan} do
      assert orphan.user_id == nil
      assert orphan.report_id == nil
      assert orphan.dnp_entry_id == nil
    end

    test "mod_notes_notable_association_null rejects two non-NULL association columns" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert {:error, changeset} =
               %ModNote{moderator_id: author.id}
               |> Ecto.Changeset.change(%{
                 body: "two targets",
                 user_id: target.id,
                 report_id: report.id
               })
               |> Ecto.Changeset.check_constraint(:target,
                 name: "mod_notes_notable_association_null"
               )
               |> Repo.insert()

      assert %{target: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "report-target notes nest the report's target preloads" do
    test "a note on a report about an image can resolve the image" do
      author = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(%{user_id: owner.id})
      report = report_fixture(image_id: image.id)

      {:ok, _note} =
        ModNotes.create_mod_note(author, %{"body" => "note on image report"},
          report_id: report.id
        )

      [{note, _body}] =
        ModNotes.list_all_mod_notes_for_target(
          fn notes -> Enum.map(notes, & &1.body) end,
          report_id: report.id
        )

      assert %Philomena.Reports.Report{} = note.report
      assert note.report.id == report.id
      assert note.report.image.id == image.id
      assert note.report.image.user.id == owner.id
    end
  end
end
