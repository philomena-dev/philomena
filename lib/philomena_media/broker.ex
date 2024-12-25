defmodule PhilomenaMedia.Broker do
  @doc """
  Out-of-process replacement for `System.cmd/2` that calls the requested
  command elsewhere, translating file accesses, and returns the result.
  """
  def cmd(command, args) do
    System.cmd("broker", [broker_addr(), "execute-command", "--", command] ++ args)
  end

  defp broker_addr do
    Application.get_env(:philomena, :broker_addr)
  end
end
