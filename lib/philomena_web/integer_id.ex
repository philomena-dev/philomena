defmodule PhilomenaWeb.IntegerId do
  @moduledoc """
  Deprecated home of `Philomena.IntegerId`.

  Id parsing moved into the domain layer so that contexts, which cannot
  reference `PhilomenaWeb`, can turn raw request ids into an ordinary
  "no such row" themselves. This module remains for legacy callers before
  everything is migrated to contexts.
  """

  defdelegate parse(id), to: Philomena.IntegerId
end
