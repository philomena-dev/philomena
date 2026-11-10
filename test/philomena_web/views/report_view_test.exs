defmodule PhilomenaWeb.ReportViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.ReportView

  test "the state cell is colored and named by the report state" do
    for {state, class, name} <- [
          {"closed", "table-success", "Closed"},
          {"in_progress", "table-warning", "In progress"},
          {"claimed", "table-danger", "Claimed"},
          {"open", "table-danger", "Open"}
        ] do
      assert ReportView.report_row_class(%{state: state}) == class
      assert ReportView.pretty_state(%{state: state}) == name
    end
  end
end
