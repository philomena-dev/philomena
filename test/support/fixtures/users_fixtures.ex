defmodule Philomena.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Users` context.
  """

  alias Philomena.Users
  alias Philomena.Users.User
  alias Philomena.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def user_fixture(attrs \\ %{}) do
    email = unique_user_email()

    {role, attrs} = Map.pop(attrs, :role)
    role = role || "user"

    {confirmed, attrs} = Map.pop(attrs, :confirmed)
    confirmed = confirmed || role != "user"

    {verified, attrs} = Map.pop(attrs, :verified)
    verified = verified || role != "user"

    {locked, attrs} = Map.pop(attrs, :locked)
    locked = locked || false

    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: email,
        email: email,
        password: valid_user_password()
      })
      |> Users.register_user()

    updates =
      [
        if role != "user" do
          fn user ->
            user
            |> Repo.preload(:roles)
            |> User.update_changeset(%{role: role}, [])
          end
        end,
        if(confirmed, do: &User.confirm_changeset/1),
        if(verified, do: &User.verify_changeset/1),
        if(locked, do: &User.lock_changeset/1)
      ]
      |> Enum.reject(&is_nil/1)

    case updates do
      [] ->
        user

      _ ->
        updates
        |> Enum.reduce(user, fn update, user -> update.(user) end)
        |> Repo.update!()
    end
  end

  def confirmed_user_fixture(attrs \\ %{}) do
    user_fixture(Map.put(attrs, :confirmed, true))
  end

  def locked_user_fixture(attrs \\ %{}) do
    user_fixture(Map.put(attrs, :locked, true))
  end

  def extract_user_token(fun) do
    {:ok, captured} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token, _] = String.split(captured.text_body, "[TOKEN]")
    token
  end
end
