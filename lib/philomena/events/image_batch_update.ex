defmodule Philomena.Events.ImageBatchUpdate do
  @enforce_keys [:image_ids, :added_tag_names, :removed_tag_names]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image_ids: [integer()],
          added_tag_names: [String.t()],
          removed_tag_names: [String.t()]
        }
end
