defmodule PhilomenaWeb.Registration.TotpControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Repo

  defp put_totp_secret(user) do
    user |> User.create_totp_secret_changeset() |> Repo.update!()
  end

  defp valid_totp_code(user), do: :pot.totp(User.totp_secret(user))

  describe "GET /registrations/totp/edit" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/registrations/totp/edit")
      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "generates a secret and redirects back on first visit", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/registrations/totp/edit")

      assert redirected_to(conn) == ~p"/registrations/totp/edit"
      assert Users.get_user!(user.id).encrypted_otp_secret
    end

    test "renders the setup page once a secret exists", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      put_totp_secret(user)

      conn = get(conn, ~p"/registrations/totp/edit")

      response = html_response(conn, 200)
      assert response =~ "Two Factor Authentication - Derpibooru"
      assert response =~ "data:image/png;base64,"
    end

    test "redirects a TOTP user who has not passed the second factor", %{conn: conn} do
      user = totp_user_fixture()
      conn = conn |> log_in_user(user) |> get(~p"/registrations/totp/edit")
      assert redirected_to(conn) == ~p"/sessions/totp/new"
    end
  end

  describe "PATCH /registrations/totp (enabling)" do
    setup :register_and_log_in_user

    test "enables TOTP with a valid code, then crashes after sending the redirect",
         %{conn: conn, user: user} do
      user = put_totp_secret(user)

      # NOTE: the success branch of update/2 returns the result of
      # Users.reindex_user/1 (a %User{}) instead of the redirect conn it
      # built, so the response is sent and then the plug pipeline raises
      # (KNOWN-ODDITIES.md).
      assert_raise RuntimeError, ~r/expected action\/2 to return a Plug.Conn/, fn ->
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => valid_totp_code(user)
          }
        })
      end

      user = Users.get_user!(user.id)
      assert user.otp_required_for_login
      assert length(user.otp_backup_codes) == 10
    end

    test "re-renders on a wrong password", %{conn: conn, user: user} do
      user = put_totp_secret(user)

      conn =
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => "wrong password",
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert html_response(conn, 200) =~ "data:image/png;base64,"
      refute Users.get_user!(user.id).otp_required_for_login
    end

    test "crashes on an invalid TOTP code", %{conn: conn, user: user} do
      put_totp_secret(user)

      # NOTE: an invalid code falls through to the backup-code check, and a
      # user who has not enabled TOTP yet has otp_backup_codes: nil —
      # Enum.any?/2 crashes, so a typo'd code while enabling 2FA is a 500
      # (KNOWN-ODDITIES.md).
      assert_raise Protocol.UndefinedError, fn ->
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => "not a code"
          }
        })
      end

      refute Users.get_user!(user.id).otp_required_for_login
    end
  end

  describe "PATCH /registrations/totp (disabling)" do
    test "disables TOTP with a valid code, with the same crash shape", %{conn: conn} do
      user = totp_user_fixture()
      conn = log_in_totp_user(conn, user)

      assert_raise RuntimeError, ~r/expected action\/2 to return a Plug.Conn/, fn ->
        patch(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => valid_user_password(),
            "twofactor_token" => valid_totp_code(user)
          }
        })
      end

      user = Users.get_user!(user.id)
      refute user.otp_required_for_login
      assert user.otp_backup_codes == []
      refute user.encrypted_otp_secret
    end
  end

  describe "PUT /registrations/totp" do
    setup :register_and_log_in_user

    test "behaves like PATCH", %{conn: conn, user: user} do
      user = put_totp_secret(user)

      conn =
        put(conn, ~p"/registrations/totp", %{
          "user" => %{
            "current_password" => "wrong password",
            "twofactor_token" => valid_totp_code(user)
          }
        })

      assert html_response(conn, 200) =~ "data:image/png;base64,"
    end
  end
end
