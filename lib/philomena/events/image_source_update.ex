defmodule Philomena.Events.ImageSourceUpdate do
  @enforce_keys [:image_id, :added_sources, :removed_sources]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image_id: integer(),
          added_sources: [String.t()],
          removed_sources: [String.t()]
        }
end
