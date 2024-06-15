defmodule PhilomenaMedia.Libavfilter.Endpoint do
  @moduledoc """
  Represents an endpoint vertex of the filter graph. Processing starts or stops here.

  An endpoint which has no input but produces one output is a source. An endpoint which has one
  input but produces no output is a sink.

  See https://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description for more information.
  """

  @type index :: non_neg_integer()
  @type pad_type :: PhilomenaMedia.Libavfilter.FilterNode.pad_type()

  @type t :: %__MODULE__{
          name: nil,
          opts: [],
          inputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list(),
          outputs: PhilomenaMedia.Libavfilter.FilterNode.pad_list(),
          index: index()
        }

  @derive [PhilomenaMedia.Libavfilter.FilterNode]
  defstruct name: nil,
            opts: [],
            inputs: [],
            outputs: [],
            index: 0

  @doc """
  Create a new source endpoint with the given pad type.

  By default, this corresponds to stream index 0. Has one output pad with name `source`.

  See the moduledoc for `m:PhilomenaMedia.Libavfilter.FilterGraph` for a usage example.
  """
  @spec new_source(index(), pad_type()) :: t()
  def new_source(index \\ 0, pad_type) do
    %__MODULE__{
      outputs: [source: pad_type],
      index: index
    }
  end

  @doc """
  Create a new sink endpoint with the given pad type.

  By default, this corresponds to stream index 0. Has one input pad with name `sink`.

  See the moduledoc for `m:PhilomenaMedia.Libavfilter.FilterGraph` for a usage example.
  """
  @spec new_sink(index(), pad_type()) :: t()
  def new_sink(index \\ 0, pad_type) do
    %__MODULE__{
      inputs: [sink: pad_type],
      index: index
    }
  end
end
