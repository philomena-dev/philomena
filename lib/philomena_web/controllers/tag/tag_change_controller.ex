defmodule PhilomenaWeb.Tag.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Tags.Tag
  alias Philomena.TagChanges
  alias Philomena.TagChanges.TagChange
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: Tag, id_name: "tag_id", id_field: "slug", persisted: true

  def index(conn, params) do
    tag = conn.assigns.tag

    tag_changes =
      TagChange
      |> order_by(desc: :id)
      |> preload([:user, image: [:user, :sources, tags: :aliases]])

    tag_change_tags =
      TagChanges.Tag
      |> where(tag_id: ^tag.id)
      |> added_filter(params)
      |> preload(tag_change: ^tag_changes)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Tag Changes for Tag `#{tag.name}'",
      tag: tag,
      tag_change_tags: tag_change_tags
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query
end
