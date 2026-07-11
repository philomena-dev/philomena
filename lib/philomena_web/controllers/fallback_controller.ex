defmodule PhilomenaWeb.FallbackController do
  @moduledoc """
  Translates the two global context error shapes into the exact HTTP responses
  the web layer produced before the controller-to-context refactor.

  Used with Phoenix `action_fallback` (which applies to HTML controllers too):
  when a controller action returns a bare `{:error, :unauthorized}` or
  `{:error, :not_found}` instead of a `Plug.Conn`, Phoenix invokes this
  controller to finish the response.

  The behavior is reproduced byte-for-byte by delegating to the existing plugs
  rather than re-implementing them:

    * `{:error, :unauthorized}` → `PhilomenaWeb.NotAuthorizedPlug` (403 text for
      AJAX requests, otherwise flash + redirect to `/`).
    * `{:error, :not_found}` → `PhilomenaWeb.NotFoundPlug` (404 text for AJAX
      requests, otherwise flash + redirect to `/`).

  This fallback handles only these two global error
  shapes. Any action whose failure path is bespoke - a redirect to a specific
  resource, a different flash, an action-specific status - keeps a visible
  `case`/`with else` clause in the controller instead of routing through here.

  A minimal `use Phoenix.Controller` is intentional: the fallback only delegates
  to plugs, so it does not need the Canary/moderation-log imports or layout
  configuration that `use PhilomenaWeb, :controller` would pull in. (`:formats`
  is required by Phoenix even though this controller renders no views itself.)
  """

  use Phoenix.Controller, formats: [json: "View", html: "View"]

  @spec call(Plug.Conn.t(), {:error, :unauthorized} | {:error, :not_found}) :: Plug.Conn.t()
  def call(conn, {:error, :unauthorized}), do: PhilomenaWeb.NotAuthorizedPlug.call(conn)
  def call(conn, {:error, :not_found}), do: PhilomenaWeb.NotFoundPlug.call(conn)
end
