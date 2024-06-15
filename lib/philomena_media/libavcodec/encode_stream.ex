defmodule PhilomenaMedia.Libavcodec.EncodeStream do
  @moduledoc """
  Represents a stream which encodes data.
  """

  @type threads :: non_neg_integer()
  @type slices :: non_neg_integer()
  @type max_muxing_queue_size :: non_neg_integer()

  @type opts :: [
          threads: threads(),
          slices: slices(),
          max_muxing_queue_size: max_muxing_queue_size()
        ]

  @type t :: %__MODULE__{
          encoder: nil | struct(),
          opts: opts()
        }

  defstruct encoder: nil,
            opts: []

  @doc """
  Constructs a new encode stream.

  See the individual encoders for additional options.
  """
  @spec new(opts(), nil | struct()) :: t()
  def new(opts, encoder \\ nil) do
    %__MODULE__{
      encoder: encoder,
      opts: Keyword.take(opts, [:threads, :slices, :max_muxing_queue_size])
    }
  end
end
