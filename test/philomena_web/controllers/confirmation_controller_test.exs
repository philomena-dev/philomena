defmodule PhilomenaWeb.ConfirmationControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Philomena.Repo
  alias Phoenix.Flash
  import Philomena.UsersFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "GET /confirmations/new" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/confirmations/new")
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /confirmations" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Users.UserToken, user_id: user.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, user: user} do
      Repo.update!(Users.User.confirm_changeset(user))

      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      refute Repo.get_by(Users.UserToken, user_id: user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/confirmations", %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Users.UserToken) == []
    end
  end

  describe "GET /confirmations/:id" do
    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Users.deliver_user_confirmation_instructions(user, url)
        end)

      conn = get(conn, ~p"/confirmations/#{token}")
      assert redirected_to(conn) == "/"
      assert Flash.get(conn.assigns.flash, :info) =~ "Account confirmed successfully"
      assert Users.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Users.UserToken) == []

      conn = get(conn, ~p"/confirmations/#{token}")
      assert redirected_to(conn) == "/"

      assert Flash.get(conn.assigns.flash, :error) =~
               "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/confirmations/oops")
      assert redirected_to(conn) == "/"

      assert Flash.get(conn.assigns.flash, :error) =~
               "Confirmation link is invalid or it has expired"

      refute Users.get_user!(user.id).confirmed_at
    end
  end
end
