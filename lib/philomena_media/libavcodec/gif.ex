defmodule PhilomenaMedia.Libavcodec.Gif do
  @moduledoc """
  Represents the `gif` encoder, which takes a video input and generates encoded output.

  ## Example

      Gif.new()

  No options are exposed. However, see https://ffmpeg.org/ffmpeg-codecs.html#GIF for
  additional information.
  """

  @type opts :: []

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          force_format: nil,
          type: :video
        }

  defstruct name: "gif",
            opts: [],
            force_format: nil,
            type: :video

  @doc """
  Construct a new GIF encoder.

  See module documentation for usage.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end
end
