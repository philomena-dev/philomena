defmodule PhilomenaMedia.Libavfilter.Scale do
  @moduledoc """
  Represents the `scale` filter, which takes a video input and generates a video output.

  Has one input pad with name `source`. Has one output pad with name `result`.

  ## Example with all options

      Scale.new(
        width: 250,
        height: 250,
        force_original_aspect_ratio: :decrease,
        force_divisible_by: 2
      )

  See https://ffmpeg.org/ffmpeg-filters.html#scale-1 for more information about the options.
  """

  @type dimension :: integer()
  @type width :: dimension()
  @type height :: dimension()
  @type force_original_aspect_ratio :: :disable | :decrease | :increase
  @type force_divisible_by :: pos_integer()

  @type opts :: [
          width: width(),
          height: height(),
          force_original_aspect_ratio: force_original_aspect_ratio(),
          force_divisible_by: force_divisible_by()
        ]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: opts(),
          inputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list(),
          outputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list()
        }

  @derive [PhilomenaMedia.Libavfilter.FilterNode]
  defstruct name: "scale",
            opts: [],
            inputs: [source: :video],
            outputs: [result: :video]

  @doc """
  Construct a new scale filter.

  See module documentation for usage.
  """
  @spec new(opts()) :: t()
  def new(opts) do
    %__MODULE__{
      opts: [
        width: Keyword.fetch!(opts, :width),
        height: Keyword.fetch!(opts, :height),
        force_original_aspect_ratio: Keyword.get(opts, :force_original_aspect_ratio, :disable),
        force_divisible_by: Keyword.get(opts, :force_divisible_by, 1)
      ]
    }
  end
end
