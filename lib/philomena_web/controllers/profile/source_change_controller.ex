defmodule PhilomenaWeb.Profile.SourceChangeController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Images.Image
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.SpoilerExecutor
  alias Philomena.Repo
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show

  plug :load_and_authorize_resource,
    model: User,
    id_name: "profile_id",
    id_field: "slug",
    persisted: true

  def index(conn, _params) do
    user = conn.assigns.user

    source_changes =
      SourceChange
      |> join(:inner, [sc], i in Image, on: sc.image_id == i.id)
      |> where(
        [sc, i],
        sc.user_id == ^user.id and not (i.user_id == ^user.id and i.anonymous == true)
      )
      |> preload([:user, image: [:user, :tags]])
      |> order_by(desc: :created_at)
      |> Repo.paginate(conn.assigns.scrivener)

    spoilers =
      SpoilerExecutor.execute_spoiler(
        conn.assigns.compiled_spoiler,
        Enum.map(source_changes, & &1.image)
      )

    render(conn, "index.html",
      title: "Source Changes for User `#{user.name}'",
      user: user,
      source_changes: source_changes,
      spoilers: spoilers
    )
  end
end
