defmodule PhilomenaWeb.Api.Json.Search.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Elasticsearch
  alias Philomena.Filters.Filter
  alias Philomena.Filters.Query
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case Query.compile(user, params["q"] || "") do
      {:ok, query} ->
        filters =
          Filter
          |> Elasticsearch.search_definition(
             %{
               query: %{
                 bool: %{
                   must: [
                     query,
                     %{bool: %{should: [%{term: %{public: true}}, %{term: %{system: true}}] ++ user_should(user)}}
                   ]
                 }
               },
               sort: %{created_at: :desc}
             },
             conn.assigns.pagination
          )
          |> Elasticsearch.search_records(preload(Filter, [:user]))

        conn
        |> put_view(PhilomenaWeb.Api.Json.FilterView)
        |> render("index.json", filters: filters, total: filters.total_entries)

      {:error, msg} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: msg})
    end
  end

  defp user_should(user) do
    case user do
      nil ->
        []

      %{role: role} when role in ~W(user assistant moderator admin) ->
        [%{term: %{user_id: user.id}}]

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end

end
