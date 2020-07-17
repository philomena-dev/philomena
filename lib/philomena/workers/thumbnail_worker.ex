defmodule Philomena.ThumbnailWorker do
  alias Philomena.Images.Thumbnailer
  alias Philomena.Elasticsearch
  alias Philomena.Images.Image
  def perform(image_id) do
    Thumbnailer.generate_thumbnails(image_id)

    PhilomenaWeb.Endpoint.broadcast!(
      "firehose",
      "image:process",
      %{image_id: image_id}
    )
    Elasticsearch.update_mapping!(Image)
  end
end
