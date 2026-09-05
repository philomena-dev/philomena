defmodule Philomena.ThumbnailWorker do
  use Oban.Worker, queue: :images, max_attempts: 5

  alias Philomena.Images.Thumbnailer
  alias Philomena.Images

  @spec enqueue(integer(), String.t()) :: :ok
  def enqueue(image_id, image_mime_type) do
    Philomena.JobQueue.enqueue(__MODULE__, %{image_id: image_id}, queue: queue(image_mime_type))
  end

  defp queue("video/webm"), do: :videos
  defp queue(_mime_type), do: :images

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"image_id" => image_id}}) do
    Thumbnailer.generate_thumbnails(image_id)

    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      "image:process",
      %{image_id: image_id}
    )

    image_id
    |> Images.load_image_for_reindex!()
    |> Images.reindex_image()

    :ok
  end
end
