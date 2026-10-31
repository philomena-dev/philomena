defmodule Philomena.Events.ImageCreate do
  @enforce_keys [:image]
  defstruct @enforce_keys

  @type t :: %__MODULE__{image: Philomena.Images.Image.t()}
end
