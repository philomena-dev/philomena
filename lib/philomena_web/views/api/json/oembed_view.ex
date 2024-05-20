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
      title: "##{image.id} - #{tag_list(image)} - #{gettext("Philomena Site")}",
      author_url: image_first_source(image),
      author_name: artist_tags(image.tags),
      provider_name: gettext("Philomena Site"),
      provider_url: PhilomenaWeb.Endpoint.url(),
      cache_age: 7200,
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
