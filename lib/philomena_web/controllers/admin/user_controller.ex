defmodule PhilomenaWeb.Admin.UserController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.UserLoader
  alias PhilomenaQuery.Search
  alias Philomena.Roles.Role
  alias Philomena.Users.User
  alias Philomena.Users
  alias Philomena.Repo

  plug :verify_authorized

  plug :load_and_authorize_resource,
    model: User,
    only: [:edit, :update],
    id_field: "slug",
    preload: [:roles]

  plug :load_roles when action in [:edit, :update]

  def index(conn, params) do
    query_string =
      case params["uq"] do
        nil -> "*"
        "" -> "*"
        query_string -> query_string
      end

    case Users.Query.compile(query_string) do
      {:ok, query} ->
        users = UserLoader.query(conn, query) |> Search.search_records(User)

        render(conn, "index.html",
          title: "Admin - Users",
          layout_class: "layout--medium",
          users: users
        )

      {:error, msg} ->
        render(conn, "index.html",
          title: "Admin - Users",
          layout_class: "layout--medium",
          users: [],
          error: msg
        )
    end
  end

  def edit(conn, _params) do
    changeset = Users.change_user(conn.assigns.user)
    render(conn, "edit.html", title: "Editing User", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    case Users.update_user(conn.assigns.user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User successfully updated.")
        |> moderation_log(details: &log_details/2, data: user)
        |> redirect(to: ~p"/profiles/#{user}")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :index, User) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp load_roles(conn, _opts) do
    assign(conn, :roles, Repo.all(Role))
  end

  defp log_details(_action, user) do
    %{
      body: "Updated user details for #{user.name}",
      subject_path: ~p"/profiles/#{user}"
    }
  end
end
