defmodule Philomena.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Users` context.
  """

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
