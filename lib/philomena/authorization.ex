defmodule Philomena.Authorization do
  @moduledoc """
  The single authorization entry point for context functions.

  Business logic moves out of controllers and into
  the domain contexts, and authorization moves with it. Context functions call
  `authorize/3` at the start of a write (or before returning a loaded record on
  a read) instead of relying on Canary plugs (`load_and_authorize_resource`) or
  hand-rolled `verify_*` plugs in the web layer.

  This is a thin wrapper over Canada: the permission rules themselves remain the
  single source of truth in `Philomena.Users.Ability`
  (`lib/philomena/users/ability.ex`) - only the call site moves. It exists so
  that contexts can turn a boolean `Canada.Can.can?/3` check into the
  `:ok | {:error, :unauthorized}` result shape that context functions return and
  that `PhilomenaWeb.FallbackController` translates back into HTTP responses.

  The actor may be `nil` (an anonymous visitor); `ability.ex` already handles
  this through the fallback `Canada.Can` implementation for `Atom`/`nil`, so no
  special-casing is required here.
  """

  @doc """
  Authorizes `actor` to perform `action` on `subject`.

  Returns `:ok` when Canada permits the action, otherwise
  `{:error, :unauthorized}`.

  `actor` may be `nil` for an anonymous visitor.

  ## Examples

      iex> authorize(user, :hide, image)
      :ok

      iex> authorize(nil, :hide, image)
      {:error, :unauthorized}

  """
  @spec authorize(actor :: any(), action :: atom(), subject :: any()) ::
          :ok | {:error, :unauthorized}
  def authorize(actor, action, subject) do
    if Canada.Can.can?(actor, action, subject), do: :ok, else: {:error, :unauthorized}
  end
end
