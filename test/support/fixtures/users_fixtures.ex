defmodule Philomena.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Users` context.
  """

  alias Philomena.Bans
  alias Philomena.Users
  alias Philomena.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def user_fixture(attrs \\ %{}) do
    email = unique_user_email()

    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: email,
        email: email,
        password: valid_user_password()
      })
      |> Users.register_user()

    user
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
    |> Users.User.confirm_changeset()
    |> Repo.update!()
  end

  def locked_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
    |> Users.User.lock_changeset()
    |> Repo.update!()
  end

  def assistant_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "assistant")
    |> Repo.update!()
  end

  def moderator_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "moderator")
    |> Repo.update!()
  end

  def admin_user_fixture(attrs \\ %{}) do
    confirmed_user_fixture(attrs)
    |> Ecto.Changeset.change(role: "admin")
    |> Repo.update!()
  end

  @doc """
  Fixture for a confirmed user with an active ban.

  The ban is issued by `banning_user` (a fresh admin when `nil`), has the
  reason "Banned in test", and is valid for one year.
  """
  def banned_user_fixture(banning_user \\ nil, attrs \\ %{}) do
    user = confirmed_user_fixture(attrs)

    {:ok, _ban} =
      Bans.create_user(banning_user || admin_user_fixture(), %{
        "user_id" => user.id,
        "reason" => "Banned in test",
        "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
      })

    user
  end

  @doc """
  Fixture for a confirmed user with TOTP (2FA) enabled.

  The generated secret can be recovered with `Philomena.Users.User.totp_secret/1`
  to produce valid codes in tests that exercise the TOTP flow itself; for
  everything else, use `PhilomenaWeb.ConnCase.log_in_totp_user/2`.
  """
  def totp_user_fixture(attrs \\ %{}) do
    hashed_backup_codes =
      Users.User.random_backup_codes()
      |> Enum.map(&Users.Password.hash_pwd_salt/1)

    confirmed_user_fixture(attrs)
    |> Users.User.create_totp_secret_changeset()
    |> Ecto.Changeset.change(
      otp_required_for_login: true,
      otp_backup_codes: hashed_backup_codes
    )
    |> Repo.update!()
  end

  @doc """
  Fixture for a deactivated user.

  If `deactivated_by_user` is `nil` the user will be deactivated by themselves.
  """
  def deactivated_user_fixture(deactivated_by_user \\ nil, attrs \\ %{}) do
    user = user_fixture(attrs)

    user
    |> Users.User.deactivate_changeset(deactivated_by_user || user)
    |> Repo.update!()
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.text_body, "[TOKEN]")
    token
  end
end
