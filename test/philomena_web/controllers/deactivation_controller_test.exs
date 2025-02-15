defmodule PhilomenaWeb.DeactivationControllerTest do
  import Philomena.TestUtilities

  use PhilomenaWeb.ConnCase, async: true

  alias Swoosh.Adapters.Local.Storage.Memory
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

      assert Memory.all()
             |> Enum.find(&(&1.subject == "Reactivation instructions for your account")) != nil

      assert_retry(fn ->
        user = Users.get_user!(user.id)
        user.deleted_by_user_id == user.id
      end)
    end
  end
end
