defmodule PhilomenaWeb.Api.Json.ProfileController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query
  import PhilomenaWeb.Api.Json.NotFound

  def show(conn, %{"id" => id}) do
    user =
      User
      |> where(id: ^id)
      |> preload(public_links: :tag, awards: :badge)
      |> Repo.one()

    if is_nil(user) or user.deleted_at do
      not_found(conn)
    else
      render(conn, "show.json", user: user)
    end
  end
end
