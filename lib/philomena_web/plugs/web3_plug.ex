defmodule PhilomenaWeb.Web3Plug do

  alias Plug.Conn
  alias PhilomenaWeb.Web3Cfg

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> Conn.assign(:web3Cfg, Web3Cfg.get())
  end
end
