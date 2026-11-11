defmodule PhilomenaWeb.Admin.AdvertViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.Admin.AdvertView

  test "dates still to come are marked success, past ones danger" do
    assert AdvertView.time_column_class(DateTime.add(DateTime.utc_now(), 3600)) == "table-success"
    assert AdvertView.time_column_class(DateTime.add(DateTime.utc_now(), -3600)) == "table-danger"
  end

  test "live state and restriction choices" do
    assert AdvertView.live_text(%{live: true}) == "Yes"
    assert AdvertView.live_text(%{live: false}) == "No"
    assert Enum.map(AdvertView.restrictions(), & &1[:value]) == ["none", "nsfw", "sfw"]
  end
end
