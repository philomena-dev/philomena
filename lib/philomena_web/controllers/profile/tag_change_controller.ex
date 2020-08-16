defmodule PhilomenaWeb.Profile.TagChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.TagChanges.TagChange
  alias Philomena.SpoilerExecutor
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show
  plug :load_resource, model: User, id_name: "profile_id", id_field: "slug", persisted: true

  def index(conn, params) do
    user = conn.assigns.user

    tag_changes =
      TagChange
      |> join(:inner, [tc], i in Image, on: tc.image_id == i.id)
      |> where(
        [tc, i],
        tc.user_id == ^user.id and not (i.user_id == ^user.id and i.anonymous == true)
      )
      |> added_filter(params)
      |> preload([:tag, :user, image: [:user]])
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.scrivener)

    spoilers =
      SpoilerExecutor.execute_spoiler(
        conn.assigns.compiled_spoiler,
        Enum.map(tag_changes, & &1.image)
      )

    render(conn, "index.html",
      title: "Tag Changes for User `#{user.name}'",
      user: user,
      tag_changes: tag_changes,
      spoilers: spoilers
    )
  end

  defp added_filter(query, %{"added" => "1"}),
    do: where(query, added: true)

  defp added_filter(query, %{"added" => "0"}),
    do: where(query, added: false)

  defp added_filter(query, _params),
    do: query
end
