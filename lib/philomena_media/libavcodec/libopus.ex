defmodule PhilomenaMedia.Libavcodec.Libopus do
  @moduledoc """
  Represents the `libopus` encoder, which takes an audio input and generates encoded output.

  ## Example

      Libopus.new()

  No options are exposed. However, see https://ffmpeg.org/ffmpeg-codecs.html#libopus-1 for
  additional information.
  """

  @type opts :: []

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          force_format: nil,
          type: :audio
        }

  defstruct name: "libopus",
            opts: [],
            force_format: nil,
            type: :audio

  @doc """
  Construct a new libopus encoder.

  See module documentation for usage.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end
end
