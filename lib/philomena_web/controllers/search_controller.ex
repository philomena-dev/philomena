defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageScope
  alias PhilomenaWeb.TagInfoRenderer
  alias Philomena.Images
  alias Philomena.Interactions

  def index(conn, _params) do
    scope = ImageScope.search_scope(conn)

    case Images.query_images(conn.assigns.actor, scope) do
      {:ok, %{images: images, tags: tags}} ->
        interactions = Interactions.user_interactions(conn.assigns.actor, images)

        render(conn, "index.html",
          title: "Searching for #{scope.q}",
          images: images,
          tags: TagInfoRenderer.render_tag_info(tags, conn),
          search_query: scope.q,
          interactions: interactions,
          layout_class: "page-wide"
        )

      {:error, msg} ->
        render(conn, "index.html",
          title: "Searching for #{scope.q}",
          images: [],
          tags: [],
          error: msg,
          search_query: scope.q
        )
    end
  end
end
