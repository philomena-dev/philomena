defmodule Philomena.ReportsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.Reports.SearchIndex
  alias Philomena.Repo

  import Philomena.ReportsFixtures
  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.GalleriesFixtures
  import Philomena.CommissionsFixtures
  import Philomena.RulesFixtures

  describe "Report.reportable_columns/0" do
    test "reportable_columns lists all seven columns" do
      assert Report.reportable_columns() == [
               :image_id,
               :comment_id,
               :post_id,
               :reported_user_id,
               :commission_id,
               :conversation_id,
               :gallery_id
             ]
    end
  end

  describe "create_report/3 single-target acceptance" do
    test "accepts an image report and sets image_id" do
      image = image_fixture()
      report = report_fixture(image_id: image.id)

      assert report.image_id == image.id
      assert Report.reportable_type(report) == "Image"
      assert Report.reportable_id(report) == image.id
    end

    test "accepts a user report and sets reported_user_id" do
      target = confirmed_user_fixture()
      report = report_fixture(reported_user_id: target.id)

      assert report.reported_user_id == target.id
      assert Report.reportable_type(report) == "User"
      assert Report.reportable_id(report) == target.id
    end

    test "accepts a gallery report and sets gallery_id" do
      gallery = gallery_fixture(confirmed_user_fixture())
      report = report_fixture(gallery_id: gallery.id)

      assert report.gallery_id == gallery.id
      assert Report.reportable_type(report) == "Gallery"
      assert Report.reportable_id(report) == gallery.id
    end

    test "accepts a commission report and sets commission_id" do
      commission = commission_fixture(confirmed_user_fixture())
      report = report_fixture(commission_id: commission.id)

      assert report.commission_id == commission.id
      assert Report.reportable_type(report) == "Commission"
      assert Report.reportable_id(report) == commission.id
    end
  end

  describe "create_report/3 target-count rejection" do
    test "rejects a report with zero targets" do
      attrs = %{
        "reason" => "no target",
        "user_agent" => "TB/1.0",
        "rule_id" => rule_fixture().id
      }

      assert {:error, changeset} =
               Reports.create_report([], attribution(), attrs)

      assert %{reportable: ["must reference exactly one target"]} = errors_on(changeset)
    end
  end

  describe "creation_changeset/4 exactly-one validation" do
    test "rejects a report referencing two targets" do
      image = image_fixture()
      target = confirmed_user_fixture()

      changeset =
        Report.creation_changeset(
          %Report{image_id: image.id, reported_user_id: target.id},
          %{"reason" => "two targets", "user_agent" => "TB/1.0"},
          attribution(),
          rule_fixture()
        )

      refute changeset.valid?
      assert %{reportable: ["must reference exactly one target"]} = errors_on(changeset)
    end

    test "rejects a report referencing no target" do
      changeset =
        Report.creation_changeset(
          %Report{},
          %{"reason" => "no target", "user_agent" => "TB/1.0"},
          attribution(),
          rule_fixture()
        )

      refute changeset.valid?
      assert %{reportable: ["must reference exactly one target"]} = errors_on(changeset)
    end
  end

  describe "reports_reportable_association_null DB constraint" do
    test "allows an all-NULL (orphan) report row" do
      assert {:ok, report} =
               %Report{}
               |> Ecto.Changeset.change(%{
                 ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
                 fingerprint: "ffff",
                 reason: "orphan"
               })
               |> Repo.insert()

      assert Report.reportable_type(report) == nil
    end

    test "rejects a report row with two non-NULL columns" do
      image = image_fixture()
      gallery = gallery_fixture(confirmed_user_fixture())

      assert {:error, changeset} =
               %Report{}
               |> Ecto.Changeset.change(%{
                 ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
                 fingerprint: "ffff",
                 reason: "two targets",
                 image_id: image.id,
                 gallery_id: gallery.id
               })
               |> Ecto.Changeset.check_constraint(:reportable,
                 name: "reports_reportable_association_null"
               )
               |> Repo.insert()

      assert %{reportable: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "orphaned report helpers" do
    setup do
      {:ok, orphan} =
        %Report{}
        |> Ecto.Changeset.change(%{
          ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
          fingerprint: "ffff",
          reason: "orphan"
        })
        |> Repo.insert()

      %{orphan: orphan}
    end

    test "reportable_type/id/reportable are nil", %{orphan: orphan} do
      assert Report.reportable_type(orphan) == nil
      assert Report.reportable_id(orphan) == nil
      assert Report.reportable(orphan) == nil
    end

    test "preload_reportable/1 leaves the virtual reportable nil", %{orphan: orphan} do
      preloaded = Reports.preload_reportable(orphan)
      assert preloaded.reportable == nil
    end
  end

  describe "close_reports/2 via the target-column API" do
    test "closes open reports for an image" do
      image = image_fixture()
      report = report_fixture(image_id: image.id)
      admin = admin_user_fixture()

      assert report.open

      assert {:ok, {1, _ids}} = Reports.close_reports([image_id: image.id], admin)

      closed = Reports.get_report!(report.id)
      refute closed.open
      assert closed.state == "closed"
      assert closed.admin_id == admin.id
    end

    test "closes open reports for a user" do
      target = confirmed_user_fixture()
      report = report_fixture(reported_user_id: target.id)
      admin = admin_user_fixture()

      assert {:ok, {1, _ids}} = Reports.close_reports([reported_user_id: target.id], admin)

      closed = Reports.get_report!(report.id)
      refute closed.open
      assert closed.state == "closed"
    end
  end

  describe "SearchIndex.as_json/1" do
    defp indexed_report(report) do
      report
      |> Repo.preload([:user, :admin])
      |> Reports.preload_reportable()
    end

    test "image report carries legacy reportable_type, reportable_id and image_id" do
      owner = confirmed_user_fixture()
      image = image_fixture(%{user_id: owner.id})
      report = report_fixture(image_id: image.id)

      json = SearchIndex.as_json(indexed_report(report))

      assert json.reportable_type == "Image"
      assert json.reportable_id == image.id
      assert json.image_id == image.id
      assert String.downcase(owner.name) in json.related_users
    end

    test "user report carries legacy reportable_type and reportable_id" do
      target = confirmed_user_fixture()
      report = report_fixture(reported_user_id: target.id)

      json = SearchIndex.as_json(indexed_report(report))

      assert json.reportable_type == "User"
      assert json.reportable_id == target.id
      assert String.downcase(target.name) in json.related_users
    end

    test "gallery report includes the gallery owner in related_users" do
      owner = confirmed_user_fixture()
      gallery = gallery_fixture(owner)
      report = report_fixture(gallery_id: gallery.id)

      json = SearchIndex.as_json(indexed_report(report))

      assert json.reportable_type == "Gallery"
      assert json.reportable_id == gallery.id
      assert json.related_users == [String.downcase(owner.name)]
      assert json.related_user_ids == [owner.id]
    end

    test "commission report carries legacy reportable_type and reportable_id" do
      owner = confirmed_user_fixture()
      commission = commission_fixture(owner)
      report = report_fixture(commission_id: commission.id)

      json = SearchIndex.as_json(indexed_report(report))

      assert json.reportable_type == "Commission"
      assert json.reportable_id == commission.id
      assert json.related_users == [String.downcase(owner.name)]
    end

    test "orphan report serializes without crashing" do
      {:ok, orphan} =
        %Report{}
        |> Ecto.Changeset.change(%{
          ip: %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32},
          fingerprint: "ffff",
          reason: "orphan"
        })
        |> Repo.insert()

      json = SearchIndex.as_json(indexed_report(orphan))

      assert json.reportable_type == nil
      assert json.reportable_id == nil
      assert json.image_id == nil
      assert json.related_users == []
      assert json.related_user_ids == []
    end
  end
end
