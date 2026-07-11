defmodule PhilomenaWeb.UserAttributionPlug do
  @moduledoc """
  This plug stores information about the current session for use in
  model attribution.

  ## Example

      plug PhilomenaWeb.UserAttributionPlug
  """

  alias Philomena.Attribution.Actor
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    {:ok, remote_ip} = EctoNetwork.INET.cast(conn.remote_ip)
    conn = Conn.fetch_cookies(conn)
    user = conn.assigns.current_user
    fingerprint = fingerprint(conn, conn.path_info)

    # Unfortunately, Elixir has no support for annotating a type of variable, so
    # just make sure the shape of this keyword list satisfies the type
    # `Philomena.Users.principal`
    principal = [
      ip: remote_ip,
      fingerprint: fingerprint,
      user: user
    ]

    # The typed equivalent of `principal`, built from the same values. Existing
    # consumers keep using the `:attributes` keyword list unchanged; contexts
    # migrated consume the `:actor` struct instead.
    actor = %Actor{ip: remote_ip, fingerprint: fingerprint, user: user}

    conn
    |> Conn.assign(:attributes, principal)
    |> Conn.assign(:actor, actor)
  end

  defp user_agent(conn) do
    case Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end

  defp fingerprint(conn, ["api" | _]) do
    "a#{:erlang.crc32(user_agent(conn))}"
  end

  defp fingerprint(conn, _) do
    conn.cookies["_ses"]
  end
end
