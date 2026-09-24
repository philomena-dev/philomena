defmodule Philomena.Events.ImageDescriptionUpdate do
  @enforce_keys [:image_id, :new_description, :old_description]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image_id: integer(),
          new_description: String.t(),
          old_description: String.t()
        }
end
