defmodule PhilomenaWeb.Api.Json.Filter.UserFilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters.Filter
  alias PhilomenaQuery.Cursor
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case user do
      nil ->
        conn
        |> put_status(:forbidden)
        |> text("")

      _ ->
        {user_filters, cursors} =
          Filter
          |> where(user_id: ^user.id)
          |> Cursor.paginate(conn.assigns.scrivener, params["search_after"], asc: :id)

        conn
        |> put_view(PhilomenaWeb.Api.Json.FilterView)
        |> render("index.json",
          cursors: cursors,
          filters: user_filters,
          total: user_filters.total_entries
        )
    end
  end
end
