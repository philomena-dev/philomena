defmodule Philomena.Authorization do
  @moduledoc """
  The single authorization entry point for context functions.

  Context functions call `authorize/3` at the start of a write
  (or before returning a loaded record on a read).

  This is a thin wrapper over Canada: the permission rules themselves remain the
  single source of truth in `Philomena.Users.Ability` (`lib/philomena/users/ability.ex`).

  The actor is permitted to be `nil` (an anonymous visitor).
  """

  alias Philomena.Attribution.Actor

  @doc """
  Authorizes `actor` to perform `action` on `subject`.

  Returns `:ok` when Canada permits the action, otherwise
  `{:error, :unauthorized}`.

  `actor` may be `nil` for an anonymous visitor. It may also be a
  `Philomena.Attribution.Actor`: permissions are decided by its `user` alone -
  the IP and fingerprint attribute the action but grant nothing - so contexts
  that take an attribution can pass it here unchanged.

  ## Examples

      iex> authorize(user, :hide, image)
      :ok

      iex> authorize(nil, :hide, image)
      {:error, :unauthorized}

      iex> authorize(%Actor{user: moderator, ip: ip}, :revert, TagChange)
      :ok

  """
  @spec authorize(actor :: any(), action :: atom(), subject :: any()) ::
          :ok | {:error, :unauthorized}
  def authorize(%Actor{user: user}, action, subject), do: authorize(user, action, subject)

  def authorize(actor, action, subject) do
    if Canada.Can.can?(actor, action, subject), do: :ok, else: {:error, :unauthorized}
  end
end
