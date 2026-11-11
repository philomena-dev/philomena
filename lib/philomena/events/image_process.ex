defmodule Philomena.Events.ImageProcess do
  @enforce_keys [:image_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{image_id: integer()}
end
