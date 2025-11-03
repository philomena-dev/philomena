defmodule PhilomenaWeb.ReactivationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Repo
  alias Philomena.Users.UserToken
  alias Philomena.Users
  import Philomena.UsersFixtures

  setup do
    %{user: deactivated_user_fixture()}
  end

  describe "GET /reactivations/:id" do
    test "renders the reactivate account page", %{conn: conn} do
      conn = get(conn, ~p"/reactivations/new")
      response = html_response(conn, 200)
      assert response =~ "<h1>Reactivate Your Account</h1>"
    end
  end

  describe "POST /reactivations/" do
    test "reactivate account page works", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_reactivation_instructions(user, url)
        end)

      assert UserToken.user_and_contexts_query(user, ["reactivate"]) |> Repo.exists?()

      assert token != nil

      conn = post(conn, ~p"/reactivations", %{"token" => token})
      assert redirected_to(conn) == ~p"/"

      user = Users.get_user!(user.id)
      assert user.deleted_by_user_id == nil

      assert not (UserToken.user_and_contexts_query(user, ["reactivate"]) |> Repo.exists?())
    end
  end
end
