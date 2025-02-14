defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Swoosh.Adapters.Local.Storage.Memory
  alias Philomena.Users
  alias Phoenix.Flash

  setup :register_and_log_in_user

  describe "GET /reactivations/:id" do
    test "renders the reactivate account page", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")
      conn = get(conn, ~p"/reactivations/pinkie-pie-is-best-pony")
      response = html_response(conn, 200)
      assert response =~ "<h1>Reactivate Your Account</h1>"
    end
  end

  describe "POST /reactivations/:id" do
    test "reactivate account page works", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/deactivations")
      reactivation_link = Memory.all() |> hd |> extract_reactivation_link_from_email
      conn = post(conn, reactivation_link)
      assert redirected_to(conn) == ~p"/"

      user = Users.get_user!(user.id)
      assert user.deleted_by_user_id == nil
    end
  end

  defp extract_reactivation_link_from_email(email = %Swoosh.Email{}) do
    Regex.scan(~r/http:\/\/localhost:4002\/reactivations\/.*/, email.text_body) |> hd |> hd
  end

end
