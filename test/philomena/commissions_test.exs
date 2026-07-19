defmodule Philomena.CommissionsTest do
  use Philomena.DataCase, async: true

  alias Philomena.Commissions
  alias Philomena.Commissions.Commission
  alias Philomena.Reports
  alias Philomena.Reports.Report
  alias Philomena.Repo

  import Philomena.CommissionsFixtures
  import Philomena.ReportsFixtures
  import Philomena.UsersFixtures

  describe "delete_commission/2" do
    test "closes the commission's open reports and nulls the target FK while keeping the row" do
      commission = commission_fixture(confirmed_user_fixture())
      report = report_fixture(commission_id: commission.id)
      admin = admin_user_fixture()

      assert report.open
      assert report.commission_id == commission.id

      assert {:ok, _commission} = Commissions.delete_commission(commission, admin)

      closed = Reports.get_report!(report.id)
      refute closed.open
      assert closed.state == "closed"
      assert closed.admin_id == admin.id
      # The FK is nilified by the database, orphaning the report as audit trail.
      assert closed.commission_id == nil
      assert Report.reportable_type(closed) == nil

      refute Repo.get(Commission, commission.id)
    end
  end
end
