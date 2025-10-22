defmodule PhilomenaWeb.DeactivationController do
  use PhilomenaWeb, :controller
  alias PhilomenaWeb.UserAuth
  alias Philomena.Users

  def show(conn, _params) do
    render(conn, "index.html", title: "Deactivate Account")
  end

  def delete(conn, _params) do
    user = conn.assigns.current_user

    Users.deactivate_user(user)
    Users.deliver_user_reactivation_instructions(user, &url(~p"/reactivations/#{&1}"))
    UserAuth.log_out_user(conn)

    conn |> redirect(to: "/")
  end
end
