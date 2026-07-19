defmodule Philomena.GalleriesTest do
  use Philomena.DataCase, async: false

  # delete_gallery/2 unindexes the gallery from OpenSearch synchronously.
  @moduletag :search

  alias Philomena.Galleries
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.Repo

  import Philomena.GalleriesFixtures
  import Philomena.ReportsFixtures
  import Philomena.UsersFixtures

  describe "delete_gallery/2" do
    test "closes the gallery's open reports and nulls the target FK while keeping the row" do
      gallery = gallery_fixture(confirmed_user_fixture())
      report = report_fixture(gallery_id: gallery.id)
      admin = admin_user_fixture()

      assert report.open
      assert report.gallery_id == gallery.id

      assert {:ok, _gallery} = Galleries.delete_gallery(gallery, admin)

      closed = Reports.get_report!(report.id)
      refute closed.open
      assert closed.state == "closed"
      assert closed.admin_id == admin.id
      # The FK is nilified by the database, orphaning the report as audit trail.
      assert closed.gallery_id == nil
      assert Enum.all?(Report.target_columns(), &is_nil(Map.get(closed, &1)))

      refute Repo.get(Philomena.Galleries.Gallery, gallery.id)
    end
  end
end
