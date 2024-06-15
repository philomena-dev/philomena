defmodule PhilomenaMedia.Libavfilter.FilterGraph do
  @moduledoc """
  Represents a complex filter graph.

  ## Example

      {graph, [source, palettegen, paletteuse, sink]} =
        FilterGraph.new([
          Endpoint.new_source(:video),
          Palettegen.new(stats_mode: :single),
          Paletteuse.new(new: true),
          Endpoint.new_sink(:video)
        ])

      graph
      |> FilterGraph.connect({source, :source}, {palettegen, :source})
      |> FilterGraph.connect({source, :source}, {paletteuse, :source})
      |> FilterGraph.connect({palettegen, :result}, {paletteuse, :palette})
      |> FilterGraph.connect({paletteuse, :result}, {sink, :sink})

  This creates the following conceptual graph:

      source --> palettegen
             |       |
             |       |
             |       v
             --------paletteuse --> sink

  See https://ffmpeg.org/ffmpeg-filters.html#Filtergraph-description for more information.
  """

  alias PhilomenaMedia.Libavfilter.FilterNode
  alias PhilomenaMedia.Libavfilter.Endpoint

  @type t :: %__MODULE__{
          forward_adjacency: %{tagged_vertex() => MapSet.t()},
          reverse_adjacency: %{tagged_vertex() => MapSet.t()},
          vertices: %{integer() => struct()},
          index: integer()
        }

  @type vertex :: integer()
  @type pad_name :: FilterNode.pad_name()
  @type pad :: {vertex(), pad_name()}

  @type pad_index :: integer()
  @type tagged_vertex :: {vertex(), pad_index()}

  defstruct forward_adjacency: %{},
            reverse_adjacency: %{},
            vertices: %{},
            index: 0

  @doc """
  Creates a new filtergraph instance with an optional list of vertices to add to the graph.

  See the moduledoc for a full example.
  """
  @spec new([struct()]) :: {t(), [vertex()]}
  def new(nodes \\ []) do
    add(%__MODULE__{}, nodes)
  end

  @doc """
  Adds the specified list of vertices to the graph.

  Returns the updated filtergraph structure and a list of vertices.
  See the moduledoc for a full example.
  """
  @spec add(t(), [struct()]) :: {t(), [vertex()]}
  def add(g, nodes) do
    {vertices, g} =
      Enum.map_reduce(nodes, g, fn node, acc ->
        {
          acc.index,
          %{acc | vertices: Map.put(acc.vertices, acc.index, node), index: acc.index + 1}
        }
      end)

    {g, vertices}
  end

  @doc """
  Connects two vertex references together with the given pad name.

  Returns the updated filtergraph structure.
  See the moduledoc for a full example.
  """
  @spec connect(t(), pad(), pad()) :: t()
  def connect(g, {output_vert, output_name}, {input_vert, input_name}) do
    output_node = Map.fetch!(g.vertices, output_vert)
    output_pad = {output_vert, pad_name_to_index!(FilterNode.outputs(output_node), output_name)}

    input_node = Map.fetch!(g.vertices, input_vert)
    input_pad = {input_vert, pad_name_to_index!(FilterNode.inputs(input_node), input_name)}

    forward_adjacency =
      Map.update(g.forward_adjacency, output_pad, MapSet.new([input_pad]), fn v ->
        MapSet.put(v, input_pad)
      end)

    reverse_adjacency =
      Map.update(g.reverse_adjacency, input_pad, MapSet.new([output_pad]), fn v ->
        MapSet.put(v, output_pad)
      end)

    %{g | forward_adjacency: forward_adjacency, reverse_adjacency: reverse_adjacency}
  end

  @spec pad_name_to_index!(FilterNode.pad_list(), FilterNode.pad_name()) :: pad_index()
  defp pad_name_to_index!(pads, pad_name) do
    pads
    |> Enum.find_index(fn {name, _type} -> name == pad_name end)
    |> case do
      nil ->
        raise "Pad #{inspect(pad_name)} not found in list #{inspect(pads)}"

      value ->
        value
    end
  end

  @doc """
  Convert the filtergraph to a textual representation.
  """
  @spec to_graph(t()) :: String.t()
  def to_graph(g) do
    g.vertices
    |> Enum.map(fn
      {_vert, %Endpoint{}} ->
        []

      {vert, node} ->
        [
          incoming_pads!(g, vert),
          FilterNode.name(node),
          encode_opts!(node),
          outgoing_pads!(g, vert),
          ";"
        ]
    end)
    |> IO.iodata_to_binary()
  end

  @spec incoming_pad!(t(), tagged_vertex()) :: iodata()
  defp incoming_pad!(g, {target_vert, target_index}) do
    [{source_vert, source_index}] =
      g.reverse_adjacency
      |> Map.fetch!({target_vert, target_index})
      |> MapSet.to_list()

    case g.vertices[source_vert] do
      %_{index: index} ->
        "[#{index}:v]"

      _ ->
        "[p#{source_vert}_#{source_index}:v]"
    end
  end

  @spec incoming_pads!(t(), vertex()) :: iodata()
  defp incoming_pads!(g, target_vert) do
    g.vertices
    |> Map.fetch!(target_vert)
    |> FilterNode.inputs()
    |> Enum.with_index()
    |> Enum.map(fn {_name, index} -> incoming_pad!(g, {target_vert, index}) end)
  end

  @spec outgoing_pad!(t(), tagged_vertex()) :: iodata()
  defp outgoing_pad!(_g, {source_vert, source_index}) do
    "[p#{source_vert}_#{source_index}:v]"
  end

  @spec outgoing_pads!(t(), vertex()) :: iodata()
  defp outgoing_pads!(g, source_vert) do
    g.vertices
    |> Map.fetch!(source_vert)
    |> FilterNode.outputs()
    |> Enum.with_index()
    |> Enum.map(fn {_name, index} -> outgoing_pad!(g, {source_vert, index}) end)
  end

  @spec encode_opts!(struct()) :: iodata()
  defp encode_opts!(filter_node)

  defp encode_opts!(%_{opts: opts}) when opts == %{} do
    ""
  end

  defp encode_opts!(%_{opts: opts}) do
    ["=", Enum.map_join(opts, ":", fn {k, v} -> "#{k}=#{v}" end)]
  end
end
