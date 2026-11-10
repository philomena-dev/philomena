defmodule PhilomenaWeb.FilterBannedUsersPlug do
  @moduledoc """
  This plug redirects back if there is a ban for the current user.
  CurrentBanPlug must also be plugged, and this must come after it.

  ## Example

      plug PhilomenaWeb.FilterBannedUsersPlug
  """
  alias PhilomenaWeb.RefusalResponse
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn.assigns.current_ban
    |> maybe_halt(conn)
    |> maybe_halt_no_fingerprint()
  end

  @doc """
  Emits the ban response: the `PhilomenaWeb.RefusalResponse` with the flash
  "You are currently banned.".

  Shared with `PhilomenaWeb.FallbackController` so the context-driven
  `{:error, :ban}` path stays byte-identical with the plug for controllers not
  yet migrated off it.
  """
  @spec ban_response(Conn.t()) :: Conn.t()
  def ban_response(conn), do: RefusalResponse.call(conn, "You are currently banned.")

  defp maybe_halt(nil, conn), do: conn

  defp maybe_halt(_current_ban, conn), do: ban_response(conn)

  defp maybe_halt_no_fingerprint(%{halted: true} = conn), do: conn
  defp maybe_halt_no_fingerprint(%{method: "GET"} = conn), do: conn

  defp maybe_halt_no_fingerprint(conn) do
    case conn.assigns.fingerprint do
      nil ->
        PhilomenaWeb.NotAuthorizedPlug.call(conn)

      _other ->
        conn
    end
  end
end
