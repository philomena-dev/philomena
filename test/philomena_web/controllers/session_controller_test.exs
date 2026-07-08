defmodule PhilomenaWeb.SessionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  setup do
    %{user: confirmed_user_fixture()}
  end

  describe "GET /sessions/new" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/sessions/new")
      html_response(conn, 200)
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/sessions/new")
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /sessions" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/registrations/edit")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ "Settings</a>"
      assert response =~ "Logout</a>"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["user_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
    end

    test "rejects an unconfirmed user with valid credentials", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert html_response(conn, 200) =~ "You must confirm your account before logging in."
      refute get_session(conn, :user_token)
    end

    test "rejects a locked user with valid credentials using the generic error", %{conn: conn} do
      user = locked_user_fixture()

      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert html_response(conn, 200) =~ "Invalid email or password"
      refute get_session(conn, :user_token)
    end

    test "logs a TOTP user in but gates them on the second factor", %{conn: conn} do
      user = totp_user_fixture()

      conn =
        post(conn, ~p"/sessions", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_token)

      # Any :ensure_totp route redirects until the TOTP phase is passed.
      conn = get(conn, ~p"/registrations/edit")
      assert redirected_to(conn) == ~p"/sessions/totp/new"
    end
  end

  describe "DELETE /sessions" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/sessions")
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = delete(conn, ~p"/sessions")
      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You must log in to access this page."
    end
  end
end
