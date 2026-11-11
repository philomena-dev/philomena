defmodule PhilomenaWeb.Admin.DnpEntryViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.Admin.DnpEntryView

  test "settled entries are success, claimed ones warning, the rest danger" do
    for {state, class} <- [
          {"closed", "table-success"},
          {"listed", "table-success"},
          {"claimed", "table-warning"},
          {"acknowledged", "table-warning"},
          {"requested", "table-danger"}
        ] do
      assert DnpEntryView.dnp_entry_row_class(%{aasm_state: state}) == class
    end
  end

  test "the state filter is a list or nothing" do
    assert DnpEntryView.state_param(["listed"]) == ["listed"]
    assert DnpEntryView.state_param("listed") == []
  end
end
