defmodule PhilomenaWeb.DeactivationControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.Users

  setup :register_and_log_in_user

  describe "GET /deactivations" do
    test "renders the deactivate account page", %{conn: conn} do
      conn = get(conn, ~p"/deactivations")
      response = html_response(conn, 200)
      assert response =~ "<h1>Deactivate Account</h1>"
    end
  end

  describe "DELETE /deactivations" do
    test "causes the user to be deactivated", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")
      assert redirected_to(conn) == ~p"/"
      conn = get(conn, ~p"/registrations/edit")
      assert redirected_to(conn) == ~p"/sessions/new"

      user = Users.get_user!(user.id)
      assert user.deleted_by_user_id == user.id
    end
  end
end
