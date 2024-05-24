defmodule PhilomenaWeb.DuplicateReportView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ImageView

  @formats_order ~W(video/webm image/svg+xml image/png image/gif image/jpeg other)

  def comparison_url(conn, image),
    do: ImageView.thumb_url(image, can?(conn, :show, image), :full)

  def largest_dimensions(images) do
    images
    |> Enum.map(&{&1.image_width, &1.image_height})
    |> Enum.max_by(fn {w, h} -> w * h end)
  end

  def background_class(%{state: "rejected"}), do: "background-danger"
  def background_class(%{state: "accepted"}), do: "background-success"
  def background_class(%{state: "claimed"}), do: "background-warning"
  def background_class(_duplicate_report), do: nil

  def file_types(%{image: image, duplicate_of_image: duplicate_of_image}) do
    source_type = String.upcase(to_string(image.image_format))
    target_type = String.upcase(to_string(duplicate_of_image.image_format))

    "(#{source_type}, #{target_type})"
  end

  def forward_merge?(%{image_id: image_id, duplicate_of_image_id: duplicate_of_image_id}),
    do: duplicate_of_image_id > image_id

  def higher_res?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do:
      duplicate_of_image.image_width > image.image_width or
        duplicate_of_image.image_height > image.image_height

  def same_res?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do:
      duplicate_of_image.image_width == image.image_width and
        duplicate_of_image.image_height == image.image_height

  def same_format?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: duplicate_of_image.image_mime_type == image.image_mime_type

  def better_format?(%{image: image, duplicate_of_image: duplicate_of_image}) do
    source_index =
      Enum.find_index(@formats_order, &(image.image_mime_type == &1)) ||
        length(@formats_order) - 1

    target_index =
      Enum.find_index(@formats_order, &(duplicate_of_image.image_mime_type == &1)) ||
        length(@formats_order) - 1

    target_index < source_index
  end

  def same_aspect_ratio?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: abs(duplicate_of_image.image_aspect_ratio - image.image_aspect_ratio) <= 0.009

  def neither_have_source?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: Enum.empty?(duplicate_of_image.sources) and Enum.empty?(image.sources)

  def same_source?(%{image: image, duplicate_of_image: duplicate_of_image}) do
    MapSet.equal?(MapSet.new(image.sources), MapSet.new(duplicate_of_image.sources))
  end

  def similar_source?(%{image: image, duplicate_of_image: duplicate_of_image}) do
    MapSet.equal?(
      MapSet.new(image.sources, &URI.parse(&1.source).host),
      MapSet.new(duplicate_of_image.sources, &URI.parse(&1.source).host)
    )
  end

  def source_on_target?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: Enum.any?(duplicate_of_image.sources) and Enum.empty?(image.sources)

  def source_on_source?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: Enum.empty?(duplicate_of_image.sources) && Enum.any?(image.sources)

  def same_artist_tags?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: MapSet.equal?(artist_tags(image), artist_tags(duplicate_of_image))

  def more_artist_tags_on_target?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: proper_subset?(artist_tags(image), artist_tags(duplicate_of_image))

  def more_artist_tags_on_source?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: proper_subset?(artist_tags(duplicate_of_image), artist_tags(image))

  def same_rating_tags?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: MapSet.equal?(rating_tags(image), rating_tags(duplicate_of_image))

  def target_is_edit?(%{duplicate_of_image: duplicate_of_image}),
    do: edit?(duplicate_of_image)

  def source_is_edit?(%{image: image}),
    do: edit?(image)

  def both_are_edits?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: edit?(image) and edit?(duplicate_of_image)

  def target_is_alternate_version?(%{duplicate_of_image: duplicate_of_image}),
    do: alternate_version?(duplicate_of_image)

  def source_is_alternate_version?(%{image: image}),
    do: alternate_version?(image)

  def both_are_alternate_versions?(%{image: image, duplicate_of_image: duplicate_of_image}),
    do: alternate_version?(image) and alternate_version?(duplicate_of_image)

  def mergeable?(%{image: image, duplicate_of_image: duplicate_of_image} = report) do
    same_rating_tags?(report) and not image.hidden_from_users and
      not duplicate_of_image.hidden_from_users and image.approved and
      duplicate_of_image.approved
  end

  def source_approved?(%{image: image}) do
    image.approved
  end

  def target_approved?(%{duplicate_of_image: image}) do
    image.approved
  end

  defp artist_tags(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.namespace == "artist"))
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp rating_tags(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.category == "rating"))
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp edit?(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.name == "edit"))
    |> Enum.any?()
  end

  defp alternate_version?(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.name == "alternate version"))
    |> Enum.any?()
  end

  defp proper_subset?(set1, set2),
    do: MapSet.subset?(set1, set2) and not MapSet.equal?(set1, set2)
end
