defmodule Philomena.BansFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Bans` context.
  """

  alias Philomena.Bans

  # Bans.create_* need a creator, the ban target, a reason, and a valid_until
  # (a RelativeDate - a plain %DateTime{} casts fine). The user ban's automatic
  # subnet ban is skipped in tests (no user_ips rows).

  @doc """
  Creates a user ban against `target` (a fresh `confirmed_user_fixture/0`
  when `nil`), created by a fresh admin.
  """
  def user_ban_fixture(target \\ nil, attrs \\ %{}) do
    target = target || Philomena.UsersFixtures.confirmed_user_fixture()

    {:ok, ban} =
      Bans.create_user(
        Philomena.UsersFixtures.admin_user_fixture(),
        Enum.into(attrs, %{
          "user_id" => target.id,
          "reason" => "Test ban reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    ban
  end

  @doc """
  Creates a subnet ban, created by a fresh admin.
  """
  def subnet_ban_fixture(attrs \\ %{}) do
    {:ok, ban} =
      Bans.create_subnet(
        Philomena.UsersFixtures.admin_user_fixture(),
        Enum.into(attrs, %{
          "specification" => "203.0.113.0/24",
          "reason" => "Test subnet reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    ban
  end

  @doc """
  Creates a fingerprint ban, created by a fresh admin.
  """
  def fingerprint_ban_fixture(attrs \\ %{}) do
    {:ok, ban} =
      Bans.create_fingerprint(
        Philomena.UsersFixtures.admin_user_fixture(),
        Enum.into(attrs, %{
          "fingerprint" => "c1836fd10ff8f27a",
          "reason" => "Test fingerprint reason",
          "valid_until" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    ban
  end
end
