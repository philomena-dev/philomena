defmodule PhilomenaWeb.Admin.SiteNoticeViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.Admin.SiteNoticeView

  test "dates still to come are marked success, past ones danger" do
    assert SiteNoticeView.time_column_class(DateTime.add(DateTime.utc_now(), 3600)) ==
             "table-success"

    assert SiteNoticeView.time_column_class(DateTime.add(DateTime.utc_now(), -3600)) ==
             "table-danger"
  end

  test "live state" do
    assert SiteNoticeView.live_text(%{live: true}) == "Yes"
    assert SiteNoticeView.live_text(%{live: false}) == "No"
  end
end
