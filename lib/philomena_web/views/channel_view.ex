defmodule PhilomenaWeb.ChannelView do
  use PhilomenaWeb, :view

  def channel_image(%{type: "LivestreamChannel", short_name: short_name}) do
    now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    PhilomenaProxy.Camo.image_url(
      "https://thumbnail.api.livestream.com/thumbnail?name=#{short_name}&rand=#{now}"
    )
  end

  def channel_image(%{type: "PicartoChannel", thumbnail_url: thumbnail_url}),
    do:
      PhilomenaProxy.Camo.image_url(thumbnail_url || "https://picarto.tv/images/missingthumb.jpg")

  def channel_image(%{type: "PiczelChannel", remote_stream_id: remote_stream_id}),
    do:
      PhilomenaProxy.Camo.image_url(
        "https://piczel.tv/api/thumbnail/stream_#{remote_stream_id}.jpg"
      )

  def channel_image(%{type: "TwitchChannel", short_name: short_name}),
    do:
      PhilomenaProxy.Camo.image_url(
        "https://static-cdn.jtvnw.net/previews-ttv/live_user_#{String.downcase(short_name)}-320x180.jpg"
      )
end
