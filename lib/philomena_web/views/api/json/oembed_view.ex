defmodule PhilomenaWeb.Api.Json.OembedView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ImageView

  def render("error.json", _assigns) do
    %{
      error: "Couldn't find an image"
    }
  end

  def render("show.json", %{image: image}) do
    site_name = Philomena.Configs.get("site_name")

    {thumbnail_url, {thumbnail_width, thumbnail_height}} =
      ImageView.thumb_url_size(image, false, :large)

    %{
      type: "photo",
      version: "1.0",
      title: "##{image.id} - #{tag_list(image)} - #{site_name}",
      author_name: artist_tags(image.tags),
      author_url: image_first_source(image),
      provider_name: site_name,
      provider_url: PhilomenaWeb.Endpoint.url(),
      # 2 hours
      cache_age: 7200,
      thumbnail_url: thumbnail_url,
      thumbnail_width: thumbnail_width,
      thumbnail_height: thumbnail_height,
      url: ImageView.pretty_url(image, true, false),
      width: image.image_width,
      height: image.image_height,
      philomena_id: image.id,
      philomena_score: image.score,
      philomena_comments: image.comments_count,
      philomena_tags: Enum.map(image.tags, & &1.name)
    }
  end

  defp artist_tags(tags) do
    tags
    |> Enum.filter(&(&1.namespace == "artist"))
    |> Enum.map_join(", ", & &1.name_in_namespace)
  end
end
