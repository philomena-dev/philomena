defmodule Philomena.ReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Reports` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.Reports

  @doc """
  Creates a report against the polymorphic `{reportable_type, reportable_id}`
  pair (e.g. `{"Image", image.id}`), reported by `user` (anonymous
  attribution when `nil`).

  Reports require a non-internal rule; when `"rule_id"` is not given, a
  fresh `Philomena.RulesFixtures.rule_fixture/1` is created for it.
  """
  def report_fixture({_type, _id} = reportable, user \\ nil, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        "reason" => "Test report reason",
        "user_agent" => "Test Browser/1.0"
      })
      |> Map.put_new_lazy("rule_id", fn -> Philomena.RulesFixtures.rule_fixture().id end)

    {:ok, report} = Reports.create_report(reportable, attribution(user), attrs)

    report
  end
end
