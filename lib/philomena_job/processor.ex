defmodule PhilomenaJob.Processor do
  @moduledoc """
  Interface implemented by processors passed to `PhilomenaJob.Supervisor`.
  """

  @doc """
  Check to see if work is available, and if so, run it.

  Return false to temporarily yield control and get called again.
  Return true only when no more work is available.
  """
  @callback check_work(keyword()) :: boolean()
end
