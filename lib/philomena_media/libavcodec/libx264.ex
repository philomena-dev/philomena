defmodule PhilomenaMedia.Libavcodec.Libx264 do
  @moduledoc """
  Represents the `libx264` (H.264) encoder, which takes a video input and generates encoded output.

  ## Example with all options

      Libx264.new(
        profile: :main,
        preset: :medium,
        crf: 18,
      )

  See https://ffmpeg.org/ffmpeg-codecs.html#libx264_002c-libx264rgb for more information about the options.
  """

  @type profile :: :baseline | :main | :high
  @type preset :: :slow | :medium
  @type qrange :: 0..51
  @type crf :: qrange()

  @type opts :: [
          profile: profile(),
          preset: preset(),
          crf: qrange()
        ]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          force_format: :yuv420p,
          type: :video
        }

  defstruct name: "libx264",
            opts: [],
            force_format: :yuv420p,
            type: :video

  @doc """
  Construct a new libx264 (H.264) encoder.

  See module documentation for usage.
  """
  @spec new(opts()) :: t()
  def new(opts) do
    %__MODULE__{
      opts: Keyword.take(opts, [:profile, :preset, :crf])
    }
  end
end
