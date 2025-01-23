defmodule Philomena.ImageVectors.BatchProcessor do
  @moduledoc """
  Batch processing interface for Philomena. See the module documentation
  in `m:Philomena.ImageVectors.Importer` for more information about how to
  use the functions in this module during maintenance.
  """

  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Thumbnailer
  alias Philomena.ImageVectors.ImageVector
  alias Philomena.Maintenance
  alias Philomena.Repo

  alias PhilomenaMedia.Analyzers
  alias PhilomenaMedia.Processors
  alias PhilomenaQuery.Batch
  alias PhilomenaQuery.Search

  alias Philomena.Repo
  import Ecto.Query

  @spec all_missing(String.t(), Keyword.t()) :: :ok
  def all_missing(type \\ "full", opts \\ []) do
    Image
    |> from(as: :image)
    |> where(not exists(where(ImageVector, [iv], iv.image_id == parent_as(:image).id)))
    |> by_image_query(type, opts)
  end

  @spec by_image_query(Ecto.Query.t(), String.t(), Keyword.t()) :: :ok
  defp by_image_query(query, type, opts) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 4)
    min = Repo.one(limit(order_by(query, asc: :id), 1)).id
    max = Repo.one(limit(order_by(query, desc: :id), 1)).id

    query
    |> Batch.query_batches(opts)
    |> Task.async_stream(
      fn query -> process_query(query, type, opts) end,
      timeout: :infinity,
      max_concurrency: max_concurrency
    )
    |> Maintenance.log_progress("BatchProcessor/#{type}", min, max)
  end

  @spec process_query(Ecto.Query.t(), String.t(), Keyword.t()) ::
          Enumerable.t({:ok, integer()})
  defp process_query(query, type, batch_opts) do
    images = Repo.all(query)
    last_id = Enum.max_by(images, & &1.id).id

    values =
      Enum.flat_map(images, fn image ->
        try do
          [process_image(image, type)]
        rescue
          ex ->
            IO.puts("While processing #{image.id}: #{inspect(ex)}")
            IO.puts(Exception.format_stacktrace(__STACKTRACE__))
            []
        end
      end)

    {_count, nil} = Repo.insert_all(ImageVector, values, on_conflict: :nothing)

    :ok =
      query
      |> preload(^Images.indexing_preloads())
      |> Search.reindex(Image, batch_opts)

    last_id
  end

  @spec process_image(%Image{}, String.t()) :: map()
  defp process_image(image = %Image{}, type) do
    file = Thumbnailer.download_image_file(image)

    {:ok, analysis} = Analyzers.analyze_path(file)
    features = Processors.features(analysis, file)

    %{
      image_id: image.id,
      type: type,
      features: features.features
    }
  end
end
