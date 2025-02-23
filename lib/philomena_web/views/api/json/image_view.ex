defmodule PhilomenaWeb.Api.Json.ImageView do
  use PhilomenaWeb, :view
  alias PhilomenaWeb.ImageView

  def render("index.json", %{images: images, interactions: interactions, total: total} = assigns) do
    %{
      images: render_many(images, PhilomenaWeb.Api.Json.ImageView, "image.json", assigns),
      interactions: interactions,
      total: total
    }
  end

  def render("show.json", %{image: image, interactions: interactions} = assigns) do
    %{
      image: render_one(image, PhilomenaWeb.Api.Json.ImageView, "image.json", assigns),
      interactions: interactions
    }
  end

  def render("image.json", %{image: image} = assigns) do
    user =
      case assigns do
        %{conn: %{assigns: %{current_user: current_user}}} -> current_user
        _ -> nil
      end

    if Canada.Can.can?(user, :show, image) do
      %{
        id: image.id,
        created_at: image.created_at,
        updated_at: image.updated_at,
        first_seen_at: image.first_seen_at,
        width: image.image_width,
        height: image.image_height,
        mime_type: image.image_mime_type,
        size: image.image_size,
        orig_size: image.image_orig_size,
        duration: image.image_duration,
        animated: image.image_is_animated,
        format: image.image_format,
        aspect_ratio: image.image_aspect_ratio,
        name: image.image_name,
        sha512_hash: image.image_sha512_hash,
        orig_sha512_hash: image.image_orig_sha512_hash,
        tags: Enum.map(image.tags, & &1.name),
        tag_ids: Enum.map(image.tags, & &1.id),
        uploader: if(!!image.user and !image.anonymous, do: image.user.name),
        uploader_id: if(!!image.user and !image.anonymous, do: image.user.id),
        wilson_score: Philomena.Images.SearchIndex.wilson_score(image),
        intensities: intensities(image),
        score: image.score,
        upvotes: image.upvotes_count,
        downvotes: image.downvotes_count,
        faves: image.faves_count,
        comment_count: image.comments_count,
        tag_count: length(image.tags),
        description: image.description,
        source_url:
          if(Enum.count(image.sources) > 0, do: Enum.at(image.sources, 0).source, else: ""),
        source_urls: Enum.map(image.sources, & &1.source),
        view_url: ImageView.pretty_url(image, true, false, false),
        representations: ImageView.thumb_urls(image, true),
        thumbnails_generated: image.thumbnails_generated,
        processed: image.processed,
        deletion_reason: nil,
        duplicate_of: image.duplicate_id,
        hidden_from_users: image.hidden_from_users,
        spoilered: spoilered(assigns, image)
      }
    else
      %{
        id: image.id,
        created_at: image.created_at,
        updated_at: image.updated_at,
        first_seen_at: image.first_seen_at,
        deletion_reason: image.deletion_reason,
        duplicate_of: image.duplicate_id,
        hidden_from_users: image.hidden_from_users
      }
    end
  end

  def render("error.json", %{changeset: changeset}) do
    %{
      errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    }
  end

  defp intensities(%{intensity: %{nw: nw, ne: ne, sw: sw, se: se}}),
    do: %{nw: nw, ne: ne, sw: sw, se: se}

  defp intensities(_), do: nil

  defp spoilered(%{conn: conn}, image),
    do: ImageView.filter_or_spoiler_hits?(conn, image)

  defp spoilered(_assigns, _image), do: false
end
