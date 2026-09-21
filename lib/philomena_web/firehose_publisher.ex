defmodule PhilomenaWeb.FirehosePublisher do
  @moduledoc """
  Transforms internal events into firehose channel broadcasts.
  """

  use GenServer

  alias Philomena.Events
  alias PhilomenaWeb.Endpoint
  alias PhilomenaWeb.Api.Json.CommentView
  alias PhilomenaWeb.Api.Json.ImageView
  alias PhilomenaWeb.Api.Json.Forum.Topic.PostView

  @doc """
  Starts the firehose broadcast server.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  @doc false
  def init(_) do
    Events.subscribe_events()

    {:ok, []}
  end

  @impl true
  @doc false
  def handle_info(message, []) do
    event(message)

    {:noreply, []}
  end

  defp event(%Events.CommentCreate{comment: comment}) do
    broadcast("comment:create", CommentView.render("show.json", %{comment: comment}))
  end

  defp event(%Events.CommentUpdate{comment: comment}) do
    broadcast("comment:update", CommentView.render("show.json", %{comment: comment}))
  end

  defp event(%Events.ImageBatchUpdate{
         image_ids: image_ids,
         added_tag_names: added_tag_names,
         removed_tag_names: removed_tag_names
       }) do
    broadcast("image:batch_tag_update", %{
      image_ids: image_ids,
      added: added_tag_names,
      removed: removed_tag_names
    })
  end

  defp event(%Events.ImageCreate{image: image}) do
    broadcast("image:create", ImageView.render("show.json", %{image: image, interactions: []}))
  end

  defp event(%Events.ImageDescriptionUpdate{
         image_id: image_id,
         new_description: new_description,
         old_description: old_description
       }) do
    broadcast("image:description_update", %{
      image_id: image_id,
      added: new_description,
      removed: old_description
    })
  end

  defp event(%Events.ImageMerge{image: image, duplicate_of_image: duplicate_of_image}) do
    broadcast("image:merge", %{
      image: ImageView.render("image.json", %{image: image}),
      duplicate_of_image: ImageView.render("image.json", %{image: duplicate_of_image})
    })
  end

  defp event(%Events.ImageProcess{image_id: image_id}) do
    broadcast("image:process", %{image_id: image_id})
  end

  defp event(%Events.ImageSourceUpdate{
         image_id: image_id,
         added_sources: added_sources,
         removed_sources: removed_sources
       }) do
    broadcast("image:source_update", %{
      image_id: image_id,
      added: added_sources,
      removed: removed_sources
    })
  end

  defp event(%Events.ImageTagUpdate{
         image_id: image_id,
         added_tag_names: added_tag_names,
         removed_tag_names: removed_tag_names
       }) do
    broadcast("image:tag_update", %{
      image_id: image_id,
      added: added_tag_names,
      removed: removed_tag_names
    })
  end

  defp event(%Events.ImageUpdate{image: image}) do
    broadcast("image:update", ImageView.render("show.json", %{image: image, interactions: []}))
  end

  defp event(%Events.PostCreate{forum: forum, topic: topic, post: post}) do
    broadcast(
      "post:create",
      PostView.render("firehose.json", %{forum: forum, topic: topic, post: post})
    )
  end

  defp event(_message) do
    nil
  end

  defp broadcast(event, result) when not is_struct(result) do
    Endpoint.broadcast!("firehose", event, result)
  end
end
