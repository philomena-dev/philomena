defmodule Philomena.ImageVectors.Importer do
  @moduledoc """
  Import logic for binary files produced by the export function of
  https://github.com/philomena-dev/philomena-ris-inference-toolkit.

  Run the following commands in a long-running terminal, like screen or tmux.
  The workflow for using the importer is as follows:

  1. Use the batch inference toolkit to get the `features.bin`.
  2. Run `philomena eval 'Philomena.ImageVectors.Importer.import_from("/path/to/features.bin")'`.
  3. Backfill the remaining images:
     `philomena eval 'Philomena.ImageVectors.BatchProcessor.all_missing("full", batch_size: 32)'`
  4. Downtime, delete and recreate the images index:
     `philomena eval 'Philomena.SearchIndexer.recreate_reindex_schema_destructive!(Philomena.Images.Image)'`.
  """

  alias Philomena.ImageVectors.ImageVector
  alias Philomena.Maintenance
  alias Philomena.Repo

  # 4 bytes unsigned id + 768 floats per feature vector * 4 bytes per float
  @row_size 4 + 768 * 4

  @typedoc "A single feature row."
  @type row :: %{
          image_id: integer(),
          type: String.t(),
          features: [float()]
        }

  @spec import_from(Path.t()) :: :ok
  # sobelow_skip ["Traversal.FileModule"]
  def import_from(batch_inference_file, type \\ "full", max_concurrency \\ 4) do
    {min, max} = get_min_and_max_id(batch_inference_file, type)

    batch_inference_file
    |> File.stream!(@row_size)
    |> Stream.chunk_every(1024)
    |> Task.async_stream(
      &process_chunk(&1, type),
      timeout: :infinity,
      max_concurrency: max_concurrency
    )
    |> Maintenance.log_progress("Importer/#{type}", min, max)
  end

  @spec process_chunk([binary()], String.t()) :: :ok
  defp process_chunk(chunk, type) do
    data = Enum.map(chunk, &unpack(&1, type))
    last_id = Enum.max_by(data, & &1.image_id).image_id

    {_count, nil} = Repo.insert_all(ImageVector, data, on_conflict: :nothing)

    last_id
  end

  @spec unpack(binary(), String.t()) :: row()
  defp unpack(row, type) do
    <<image_id::little-unsigned-integer-size(32), rest::binary-size(3072)>> = row
    features = for <<v::little-float-size(32) <- rest>>, do: v

    %{
      image_id: image_id,
      type: type,
      features: features
    }
  end

  @spec get_min_and_max_id(Path.t(), String.t()) :: {integer(), integer()}
  defp get_min_and_max_id(path, type) do
    stat = File.stat!(path)
    last_row = stat.size - @row_size

    %{image_id: min} = get_single_row(path, 0, type)
    %{image_id: max} = get_single_row(path, last_row, type)

    {min, max}
  end

  @spec get_single_row(Path.t(), integer(), String.t()) :: row()
  # sobelow_skip ["Traversal.FileModule"]
  defp get_single_row(path, offset, type) do
    path
    |> File.stream!(@row_size, read_offset: offset)
    |> Enum.at(0)
    |> unpack(type)
  end
end
