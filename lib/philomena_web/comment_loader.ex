defmodule PhilomenaWeb.CommentLoader do
  alias Philomena.Comments.Comment
  alias Philomena.Repo
  alias PhilomenaQuery.Search
  import Ecto.Query

  def load_comments(conn, image) do
    user = conn.assigns.current_user
    direction = load_direction(user)

    query_all(conn, image)
    |> order_by([{^direction, :created_at}])
    |> preload([:image, :deleted_by, user: [awards: :badge]])
    |> Repo.paginate(conn.assigns.comment_scrivener)
  end

  def find_page(conn, image, comment_id) do
    user = conn.assigns.current_user

    comment =
      Comment
      |> where(image_id: ^image.id)
      |> where(id: ^comment_id)
      |> Repo.one!()

    offset =
      query_all(conn, image)
      |> filter_direction(comment.created_at, user)
      |> Repo.aggregate(:count, :id)

    page_size = conn.assigns.comment_scrivener[:page_size]

    # Pagination starts at page 1
    div(offset, page_size) + 1
  end

  def last_page(conn, image) do
    offset =
      query_all(conn, image)
      |> Repo.aggregate(:count, :id)

    page_size = conn.assigns.comment_scrivener[:page_size]

    # Pagination starts at page 1
    div(offset, page_size) + 1
  end

  defp query_all(conn, image) do
    user = conn.assigns.current_user
    show_hidden? = staff?(user)

    Comment
    |> where(image_id: ^image.id)
    |> filter_deleted(show_hidden?)
    |> filter_non_approved(user, show_hidden?)
  end

  defp staff?(%{role: role}) when role in ~W(assistant moderator admin), do: true
  defp staff?(_user), do: false

  defp load_direction(%{comments_newest_first: false}), do: :asc
  defp load_direction(_user), do: :desc

  defp filter_deleted(query, true), do: query
  defp filter_deleted(query, _show_hidden?), do: where(query, [c], not c.destroyed_content)

  defp filter_non_approved(query, _user, true), do: query

  defp filter_non_approved(query, %{id: user_id}, _show_hidden?),
    do: where(query, [c], c.approved or c.user_id == ^user_id)

  defp filter_non_approved(query, _user, _show_hidden?),
    do: where(query, [c], c.approved)

  defp filter_direction(query, time, %{comments_newest_first: false}),
    do: where(query, [c], c.created_at <= ^time)

  defp filter_direction(query, time, _user),
    do: where(query, [c], c.created_at >= ^time)

  def query(conn, body, options \\ []) do
    pagination = Keyword.get(options, :pagination, conn.assigns.pagination)
    show_hidden? = Keyword.get(options, :show_hidden, true)

    user = conn.assigns.current_user
    filter = conn.assigns.current_filter
    filters = create_filters(user, filter, show_hidden?)

    Search.search_definition(
      Comment,
      %{
        query: %{
          bool: %{
            must: body,
            must_not: filters
          }
        },
        sort: %{posted_at: :desc}
      },
      pagination
    )
  end

  defp create_filters(user, filter, show_hidden?) do
    show_hidden? = show_hidden? and staff?(user)

    [%{terms: %{"image.tag_ids" => filter.hidden_tag_ids}}]
    |> hide_deleted(show_hidden?)
    |> hide_non_approved(user, show_hidden?)
  end

  defp hide_deleted(filters, true), do: filters

  defp hide_deleted(filters, _show_hidden?),
    do: [
      %{term: %{hidden_from_users: true}},
      %{term: %{"image.hidden_from_users" => true}}
      | filters
    ]

  defp hide_non_approved(filters, _user, true), do: filters

  defp hide_non_approved(filters, %{id: user_id}, _show_hidden?),
    do: [
      %{
        bool: %{
          should: [%{term: %{approved: false}}, %{term: %{"image.approved" => false}}],
          must_not: [%{term: %{user_id: user_id}}]
        }
      }
      | filters
    ]

  defp hide_non_approved(filters, _user, _show_hidden?),
    do: [
      %{term: %{approved: false}},
      %{term: %{"image.approved" => false}}
      | filters
    ]
end
