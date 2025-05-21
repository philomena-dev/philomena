defmodule PhilomenaWeb.Api.Json.Filter.SystemFilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters.Filter
  alias PhilomenaQuery.Cursor
  import Ecto.Query

  def index(conn, params) do
    {system_filters, cursors} =
      Filter
      |> where(system: true)
      |> Cursor.paginate(conn.assigns.scrivener, params["search_after"], asc: :id)

    conn
    |> put_view(PhilomenaWeb.Api.Json.FilterView)
    |> render("index.json",
      cursors: cursors,
      filters: system_filters,
      total: system_filters.total_entries
    )
  end
end
