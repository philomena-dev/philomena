defmodule Philomena.DuplicateReportsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.DuplicateReports` context.
  """

  alias Philomena.DuplicateReports

  @doc """
  Creates an open duplicate report claiming `source` duplicates `target`.

  `user` (default `nil`, i.e. anonymous) is recorded as the reporter via the
  controller-style attribution map. Extra `attrs` are string-keyed the way the
  controller passes them (only `"reason"` is cast).
  """
  def duplicate_report_fixture(source, target, user \\ nil, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{"reason" => "These look identical"})

    {:ok, duplicate_report} =
      DuplicateReports.create_duplicate_report(source, target, %{user: user}, attrs)

    duplicate_report
  end
end
