defmodule PhilomenaWeb.UserLoader do
  alias PhilomenaQuery.Search
  alias Philomena.Users.User

  @sortable_fields ~W(
    name
    confirmed_at
    updated_at
    deleted_at
    uploads_count
    images_favourited_count
    comments_posted_count
    votes_cast_count
    metadata_updates_count
    forum_posts_count
    topic_count
    _score
  )

  def query(conn, body, options \\ []) do
    pagination = Keyword.get(options, :pagination, conn.assigns.pagination)
    sort = Keyword.get(options, :sort) || parse_sort(conn.params)

    Search.search_definition(
      User,
      %{
        query: body,
        sort: sort
      },
      pagination
    )
  end

  defp parse_sort(params),
    do: parse_sf(params, parse_sd(params))

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc), do: sd
  defp parse_sd(_params), do: "desc"

  defp parse_sf(%{"sf" => sf}, sd) when sf in @sortable_fields,
    do: [%{sf => sd}, %{"id" => sd}]

  defp parse_sf(_params, sd),
    do: [%{"id" => sd}]
end
