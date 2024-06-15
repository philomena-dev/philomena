defmodule PhilomenaMedia.Libavcodec.Libvpx do
  @moduledoc """
  Represents the `libvpx` (VP8) encoder, which takes a video input and generates encoded output.

  ## Example with all options

      Libvpx.new(
        deadline: :good,
        "cpu-used": 5,
        crf: 31
      )

  See https://ffmpeg.org/ffmpeg-codecs.html#libvpx for more information about the options.
  """

  @type deadline :: :best | :good | :realtime
  @type cpu_used :: -16..16
  @type qrange :: 0..63
  @type crf :: qrange()

  @type opts :: [
          deadline: deadline(),
          "cpu-used": cpu_used(),
          crf: qrange()
        ]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          force_format: :yuv420p,
          type: :video
        }

  defstruct name: "libvpx",
            opts: [],
            force_format: :yuv420p,
            type: :video

  @doc """
  Construct a new libvpx (VP8) encoder.

  See module documentation for usage.
  """
  @spec new(opts()) :: t()
  def new(opts) do
    %__MODULE__{
      opts: Keyword.take(opts, [:deadline, :"cpu-used", :crf])
    }
  end
end
