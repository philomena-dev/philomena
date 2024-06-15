defmodule PhilomenaMedia.Libavcodec.Aac do
  @moduledoc """
  Represents the `aac` encoder, which takes an audio input and generates encoded output.

  ## Example

      Aac.new()

  No options are exposed. However, see https://ffmpeg.org/ffmpeg-codecs.html#aac for
  additional information.
  """

  @type opts :: []

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          force_format: nil,
          type: :audio
        }

  defstruct name: "aac",
            opts: [],
            force_format: nil,
            type: :audio

  @doc """
  Construct a new AAC encoder.

  See module documentation for usage.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end
end
