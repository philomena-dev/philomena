defmodule Philomena.ThumbnailWorker do
  use Oban.Worker, queue: :images, max_attempts: 5

  alias Philomena.Images.Thumbnailer
  alias Philomena.Images

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"args" => args}}), do: apply(__MODULE__, :perform, args)

  def perform(image_id) do
    Thumbnailer.generate_thumbnails(image_id)

    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      "image:process",
      %{image_id: image_id}
    )

    image_id
    |> Images.load_image_for_reindex!()
    |> Images.reindex_image()
  end
end
