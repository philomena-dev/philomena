defmodule Philomena.Events.ImageTagUpdate do
  @enforce_keys [:image_id, :added_tag_names, :removed_tag_names]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image_id: integer(),
          added_tag_names: [String.t()],
          removed_tag_names: [String.t()]
        }
end
