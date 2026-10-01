defmodule Philomena.ThumbnailWorker do
  alias Philomena.Events
  alias Philomena.Images.Thumbnailer
  alias Philomena.Images

  def perform(image_id) do
    Thumbnailer.generate_thumbnails(image_id)

    Events.broadcast(%Events.ImageProcess{image_id: image_id})

    image_id
    |> Images.load_image_for_reindex!()
    |> Images.reindex_image()
  end
end
