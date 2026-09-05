defmodule Philomena.ThumbnailWorker do
  use Oban.Worker, queue: :images, max_attempts: 5

  alias Philomena.Images.Thumbnailer
  alias Philomena.Multi

  @spec put_enqueue(Multi.t(), integer(), String.t()) :: Multi.t()
  def put_enqueue(%Multi{} = multi, image_id, image_mime_type) do
    Philomena.JobQueue.put_enqueue(multi, __MODULE__, %{image_id: image_id},
      queue: queue(image_mime_type)
    )
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

    :ok
  end
end
