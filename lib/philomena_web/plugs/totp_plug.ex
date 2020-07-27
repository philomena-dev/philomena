defmodule PhilomenaWeb.TotpPlug do
  @moduledoc """
  This plug ensures that a user session has a valid TOTP.

  ## Example

      plug PhilomenaWeb.TotpPlug
  """

  alias PhilomenaWeb.Router.Helpers, as: Routes

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case conn.assigns.current_user do
      nil -> conn
      user -> maybe_require_totp_phase(user, conn)
    end
  end

  defp maybe_require_totp_phase(%{otp_required_for_login: nil}, conn), do: conn
  defp maybe_require_totp_phase(%{otp_required_for_login: false}, conn), do: conn

  defp maybe_require_totp_phase(_user, conn) do
    conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.get_session(:totp_valid_at)
    |> case do
      nil ->
        conn
        |> Phoenix.Controller.redirect(to: Routes.session_totp_path(conn, :new))
        |> Plug.Conn.halt()

      _valid_at ->
        conn
    end
  end

  @doc false
  @spec update_valid_totp_at_for_session(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_valid_totp_at_for_session(conn, _user) do
    conn
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.put_session(:totp_valid_at, DateTime.utc_now())
  end
end
