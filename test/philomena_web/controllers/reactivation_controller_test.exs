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
      conn = get(conn, ~p"/reactivations/pinkie-pie-is-best-pony")
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

    test "flashes the same message for an invalid token without reactivating",
         %{conn: conn, user: user} do
      conn = post(conn, ~p"/reactivations", %{"token" => "oops"})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If the token provided was valid, your account has been reactivated."

      assert Users.get_user!(user.id).deleted_by_user_id
    end

    test "raises without a token param", %{conn: conn} do
      assert_raise Phoenix.ActionClauseError, fn ->
        post(conn, ~p"/reactivations", %{})
      end
    end
  end

  describe "when already logged in" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "GET /reactivations/:id redirects to the homepage", %{conn: conn} do
      conn = get(conn, ~p"/reactivations/some-token")
      assert redirected_to(conn) == "/"
    end

    test "POST /reactivations redirects to the homepage", %{conn: conn} do
      conn = post(conn, ~p"/reactivations", %{"token" => "oops"})
      assert redirected_to(conn) == "/"
    end
  end
end
