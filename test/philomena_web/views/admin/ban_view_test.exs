defmodule PhilomenaWeb.Admin.BanViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.Admin.BanView

  test "only an enabled ban that has not expired is marked active" do
    future = DateTime.add(DateTime.utc_now(), 3600)
    past = DateTime.add(DateTime.utc_now(), -3600)

    assert BanView.ban_row_class(%{valid_until: future, enabled: true}) == "table-success"
    assert BanView.ban_row_class(%{valid_until: future, enabled: false}) == "table-danger"
    assert BanView.ban_row_class(%{valid_until: past, enabled: true}) == "table-danger"
  end

  test "paging keeps the non-empty filters only" do
    params = %{"bq" => "spam", "ip" => "", "user_id" => nil, "page" => "2", "fingerprint" => "c1"}

    assert BanView.page_params(params) == [{"bq", "spam"}, {"fingerprint", "c1"}]
  end
end
