defmodule PhilomenaWeb.Page.HistoryController do
  use PhilomenaWeb, :controller

  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages.Version
  alias Philomena.Repo
  alias PhilomenaWeb.MarkdownRenderer
  import Ecto.Query

  plug :load_resource, model: StaticPage, id_name: "page_id", id_field: "slug", required: true

  def index(conn, _params) do
    page = conn.assigns.static_page

    versions =
      Version
      |> where(static_page_id: ^page.id)
      |> preload(:user)
      |> order_by(desc: :created_at, desc: :id)
      |> Repo.all()
      |> generate_differences()

    render(conn, "index.html",
      title: "Revision History for Page `#{page.title}'",
      layout_class: "layout--wide",
      versions: versions
    )
  end

  # Versions store the body as it was after each edit, so a version's diff is
  # taken from the next-older version's body to its own. The oldest version is
  # the page's creation and diffs against the empty document.
  defp generate_differences(versions) do
    versions
    |> Enum.reverse()
    |> Enum.map_reduce(nil, fn version, previous_body ->
      difference = MarkdownRenderer.render_diff(previous_body, version.body)

      {%{version | difference: difference}, version.body}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
