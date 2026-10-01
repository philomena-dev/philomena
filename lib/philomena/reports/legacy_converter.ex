defmodule Philomena.Reports.LegacyConverter do
  @moduledoc """
  Converts legacy report reasons to their structured rule and reason fields.
  """

  import Ecto.Query

  alias PhilomenaQuery.Batch
  alias Philomena.Reports.Report
  alias Philomena.Rules
  alias Philomena.Reports

  @reason_regex ~r/^(Rule|Other|Takedown|Verification|Approval|Review|System)([^:]*): (.*)$/

  defp convert_report(%Report{rule_id: 1, reason: report_reason} = report, rules) do
    case Regex.run(@reason_regex, report_reason) do
      [_, prefix, suffix, reason] ->
        rule = Map.get(rules, "#{prefix}#{suffix}", %{id: 1})

        Reports.convert_legacy_report!(report, reason, rule)

      _other ->
        {:error, report}
    end
  end

  defp convert_report(report, _rules), do: {:ok, report}

  @doc """
  Converts legacy report reasons to their structured rule and reason fields.

  ## Examples

      iex> convert_reports!()
      :ok

  """
  @spec convert_reports!() :: :ok
  def convert_reports! do
    rules =
      Rules.list_reportable_rules()
      |> Map.new(&{&1.name, &1})

    Report
    |> preload(:rule)
    |> Batch.records(batch_size: 128)
    |> Enum.each(&convert_report(&1, rules))
  end
end
