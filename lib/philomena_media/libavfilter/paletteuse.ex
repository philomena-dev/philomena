defmodule PhilomenaMedia.Libavfilter.Paletteuse do
  @moduledoc """
  Represents the `paletteuse` filter, which takes two video inputs and generates a video output.

  The first input is the video stream, and the second input is the a 256-color palette.
  Video colors are mapped onto the palette using a kd-tree quantization algorithm.

  Has two input pads with names `source` and `palette`. Has one output pad with name `result`.

  ## Example with all options

      Paletteuse.new(
        dither: :bayer,
        bayer_scale: 5,
        diff_mode: :rectangle,
        new: false,
        alpha_threshold: 255
      )

  See https://ffmpeg.org/ffmpeg-filters.html#paletteuse for more information about the options.
  """

  @type dither :: :bayer | :none
  @type bayer_scale :: 0..5
  @type diff_mode :: :none | :rectangle
  @type new :: boolean()
  @type alpha_threshold :: 0..255

  @type opts :: [
          dither: dither(),
          bayer_scale: bayer_scale(),
          diff_mode: diff_mode(),
          new: new(),
          alpha_threshold: alpha_threshold()
        ]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          inputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list(),
          outputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list()
        }

  @derive [PhilomenaMedia.Libavfilter.FilterNode]
  defstruct name: "paletteuse",
            opts: [],
            inputs: [source: :video, palette: :video],
            outputs: [result: :video]

  @doc """
  Construct a new paletteuse filter.

  See module documentation for usage.
  """
  @spec new(opts()) :: t()
  def new(opts) do
    %__MODULE__{
      opts: [
        dither: Keyword.get(opts, :dither, :bayer),
        bayer_scale: Keyword.get(opts, :bayer_scale, 5),
        diff_mode: Keyword.get(opts, :diff_mode, :rectangle),
        new: Keyword.get(opts, :new, false),
        alpha_threshold: Keyword.get(opts, :alpha_threshold, 255)
      ]
    }
  end
end
