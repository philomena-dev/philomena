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

  describe "ModNote.column_for_type/1" do
    test "maps each legacy notable type to its column" do
      assert ModNote.column_for_type("User") == :user_id
      assert ModNote.column_for_type("Report") == :report_id
      assert ModNote.column_for_type("DnpEntry") == :dnp_entry_id
    end

    test "returns nil for an unknown type" do
      assert ModNote.column_for_type("Image") == nil
    end
  end

  describe "create_mod_note/2 mapping via the string API" do
    test "a User note sets user_id" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()

      {:ok, note} =
        ModNotes.create_mod_note(author, %{
          "notable_type" => "User",
          "notable_id" => target.id,
          "body" => "watching"
        })

      assert note.user_id == target.id
      assert note.report_id == nil
      assert note.dnp_entry_id == nil
      assert ModNote.notable_type(note) == "User"
      assert ModNote.notable_id(note) == target.id
    end

    test "a Report note sets report_id" do
      author = moderator_user_fixture()
      image = image_fixture()
      report = report_fixture({"Image", image.id})

      {:ok, note} =
        ModNotes.create_mod_note(author, %{
          "notable_type" => "Report",
          "notable_id" => report.id,
          "body" => "watching report"
        })

      assert note.report_id == report.id
      assert note.user_id == nil
      assert ModNote.notable_type(note) == "Report"
      assert ModNote.notable_id(note) == report.id
    end

    test "a DnpEntry note sets dnp_entry_id" do
      author = moderator_user_fixture()
      requester = confirmed_user_fixture()
      tag = tag_fixture()
      dnp_entry = dnp_entry_fixture(requester, tag)

      {:ok, note} =
        ModNotes.create_mod_note(author, %{
          "notable_type" => "DnpEntry",
          "notable_id" => dnp_entry.id,
          "body" => "watching dnp"
        })

      assert note.dnp_entry_id == dnp_entry.id
      assert note.user_id == nil
      assert ModNote.notable_type(note) == "DnpEntry"
      assert ModNote.notable_id(note) == dnp_entry.id
    end
  end

  describe "create_mod_note/2 validation" do
    test "rejects a missing notable type and id" do
      author = moderator_user_fixture()

      assert {:error, changeset} =
               ModNotes.create_mod_note(author, %{"body" => "orphan attempt"})

      errors = errors_on(changeset)
      assert errors[:notable_type] == ["can't be blank"]
      assert errors[:notable_id] == ["can't be blank"]
    end

    test "rejects an unknown notable type" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()

      assert {:error, changeset} =
               ModNotes.create_mod_note(author, %{
                 "notable_type" => "Image",
                 "notable_id" => target.id,
                 "body" => "bad type"
               })

      errors = errors_on(changeset)
      assert errors[:notable_type] == ["is invalid"]
      # No column is set for an unknown type, so the exactly-one check also
      # fails.
      assert errors[:notable] == ["must reference exactly one target"]
    end
  end

  describe "orphaned mod note helpers and DB constraint" do
    setup do
      author = moderator_user_fixture()

      {:ok, orphan} =
        %ModNote{moderator_id: author.id}
        |> Ecto.Changeset.change(%{body: "orphan"})
        |> Repo.insert()

      %{orphan: orphan}
    end

    test "notable_type/id/notable are nil on an all-NULL note", %{orphan: orphan} do
      assert ModNote.notable_type(orphan) == nil
      assert ModNote.notable_id(orphan) == nil
      assert ModNote.notable(orphan) == nil
    end

    test "mod_notes_notable_association_null rejects two non-NULL association columns" do
      author = moderator_user_fixture()
      target = confirmed_user_fixture()
      image = image_fixture()
      report = report_fixture({"Image", image.id})

      assert {:error, changeset} =
               %ModNote{moderator_id: author.id}
               |> Ecto.Changeset.change(%{
                 body: "two targets",
                 user_id: target.id,
                 report_id: report.id
               })
               |> Ecto.Changeset.check_constraint(:notable,
                 name: "mod_notes_notable_association_null"
               )
               |> Repo.insert()

      assert %{notable: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "report-target notes nest the report's reportable preloads" do
    test "a note on a report about an image can resolve the image" do
      author = moderator_user_fixture()
      owner = confirmed_user_fixture()
      image = image_fixture(%{user_id: owner.id})
      report = report_fixture({"Image", image.id})

      {:ok, _note} =
        ModNotes.create_mod_note(author, %{
          "notable_type" => "Report",
          "notable_id" => report.id,
          "body" => "note on image report"
        })

      [{note, _body}] =
        ModNotes.list_all_mod_notes_by_type_and_id(
          "Report",
          report.id,
          fn notes -> Enum.map(notes, & &1.body) end
        )

      assert %Philomena.Reports.Report{} = note.notable
      assert note.notable.id == report.id
      assert note.notable.image.id == image.id
      assert note.notable.image.user.id == owner.id
    end
  end
end
