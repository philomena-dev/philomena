defmodule Philomena.Attribution.Actor do
  @moduledoc """
  The typed actor/attribution passed to context functions.

  Context functions that act on behalf of someone take the actor first.
  Where that actor is really an *attribution* (a user together with the
  request's IP and browser fingerprint - e.g. image uploads,
  tag changes, posts), this struct formalizes the shape that
  `PhilomenaWeb.UserAttributionPlug` builds so context signatures can be typed.

  It carries the same three values as the existing `t:Philomena.Users.principal/0`
  keyword list (`lib/philomena/users.ex`), which many contexts still consume via
  Access (`attribution[:user]`).
  """

  alias Philomena.Users.User

  @enforce_keys [:ip]
  defstruct user: nil, ip: nil, fingerprint: nil

  # `%User{}` is used rather than `User.t()` to match the existing
  # `t:Philomena.Users.principal/0` type: the `User` schema does not define a
  # `t/0` type, so referencing it here would fail `--warnings-as-errors`.
  @type t :: %__MODULE__{
          user: %User{} | nil,
          ip: EctoNetwork.INET.t(),
          fingerprint: String.t() | nil
        }
end
