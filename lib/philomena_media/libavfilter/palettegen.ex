defmodule PhilomenaMedia.Libavfilter.Palettegen do
  @moduledoc """
  Represents the `palettegen` filter, which takes a video input and generates a video output.

  The palette for each frame processed is generated using the median cut algorithm.

  Has one input pad with name `source`. Has one output pad with name `result`.

  ## Example with all options

      Palettegen.new(
        max_colors: 255,
        reserve_transparent: true,
        stats_mode: :diff
      )

  See https://ffmpeg.org/ffmpeg-filters.html#palettegen for more information about the options.
  """

  @type max_colors :: 0..256
  @type reserve_transparent :: boolean()
  @type stats_mode :: :full | :diff | :single

  @type opts :: [
          max_colors: max_colors(),
          reserve_transparent: reserve_transparent(),
          stats_mode: stats_mode()
        ]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          inputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list(),
          outputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list()
        }

  @derive [PhilomenaMedia.Libavfilter.FilterNode]
  defstruct name: "palettegen",
            opts: [],
            inputs: [source: :video],
            outputs: [result: :video]

  @doc """
  Construct a new palettegen filter.

  See module documentation for usage.
  """
  @spec new(opts()) :: t()
  def new(opts) do
    %__MODULE__{
      opts: [
        max_colors: Keyword.get(opts, :max_colors, 255),
        reserve_transparent: Keyword.get(opts, :reserve_transparent, true),
        stats_mode: Keyword.get(opts, :stats_mode, :diff)
      ]
    }
  end
end
