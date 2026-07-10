defmodule PhilomenaWeb.Api.Json.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters.Filter
  alias PhilomenaWeb.IntegerId
  alias Philomena.Repo
  import Ecto.Query
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    filter = load_filter(id)

    if Canada.Can.can?(user, :show, filter) do
      render(conn, "show.json", filter: filter)
    else
      not_found(conn)
    end
  end

  defp load_filter(id) do
    case IntegerId.parse(id) do
      {:ok, id} ->
        Filter
        |> where(id: ^id)
        |> preload(:user)
        |> Repo.one()

      :error ->
        nil
    end
  end
end
