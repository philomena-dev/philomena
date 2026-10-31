defmodule Philomena.Events.ImageMerge do
  @enforce_keys [:image, :duplicate_of_image]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          image: Philomena.Images.Image.t(),
          duplicate_of_image: Philomena.Images.Image.t()
        }
end
