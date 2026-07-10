defmodule Philomena.DnpEntriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.DnpEntries` context.
  """

  alias Philomena.DnpEntries

  @doc """
  Creates a DNP entry for `tag`, requested by `user`. Starts out in the
  default `"requested"` state; pass `state:` to transition it afterwards
  (the transition is attributed to the requesting user, the way a mod
  processing the request would be recorded).

  String-keyed attrs mirror the DNP controller form (`"dnp_type"`,
  `"reason"`, `"conditions"`, `"hide_reason"`, `"instructions"`).
  """
  def dnp_entry_fixture(user, tag, attrs \\ %{}) do
    {state, attrs} = Map.pop(attrs, :state)

    attrs =
      Enum.into(attrs, %{
        "tag_id" => to_string(tag.id),
        "dnp_type" => "No Edits",
        "reason" => "Test DNP reason",
        "conditions" => "Test DNP conditions"
      })

    {:ok, dnp_entry} = DnpEntries.create_dnp_entry(user, [tag], attrs)

    case state do
      nil ->
        dnp_entry

      state ->
        {:ok, dnp_entry} = DnpEntries.transition_dnp_entry(dnp_entry, user, state)
        dnp_entry
    end
  end
end
