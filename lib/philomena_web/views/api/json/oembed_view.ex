defmodule PhilomenaWeb.Api.Json.OembedView do
  use PhilomenaWeb, :view

  def render("error.json", _assigns) do
    %{
      error: "Couldn't find an image"
    }
  end

  def render("show.json", %{image: image}) do
    %{
      version: "1.0",
      type: "photo",
      title: "##{image.id} - #{image.tag_list_cache} - Ponybooru",
      author_url: image.source_url || "",
      author_name: artist_tags(image.tags),
      provider_name: "Ponybooru",
      provider_url: PhilomenaWeb.Endpoint.url(),
      cache_age: 7200,
      ponybooru_id: image.id,
      ponybooru_score: image.score,
      ponybooru_comments: image.comments_count,
      ponybooru_tags: Enum.map(image.tags, & &1.name)
    }
  end

  defp artist_tags(tags) do
    tags
    |> Enum.filter(&(&1.namespace == "artist"))
    |> Enum.map_join(", ", & &1.name_in_namespace)
  end
end
