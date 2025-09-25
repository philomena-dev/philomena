defmodule PhilomenaMedia.Remote do
  @doc """
  Out-of-process replacement for `System.cmd/2` that calls the requested
  command elsewhere, translating file accesses, and returns the result.
  """
  def cmd(command, args) do
    :ok = Philomena.Native.async_process_command(mediaproc_addr(), command, args)

    receive do
      {:process_command_reply, command_reply} ->
        {command_reply.stdout, command_reply.status}
    end
  end

  @doc """
  Gets a feature vector for the given image path to use in reverse image search.
  """
  def get_features(path) do
    :ok = Philomena.Native.async_get_features(mediaproc_addr(), path)

    receive do
      {:get_features_reply, get_features_reply} ->
        get_features_reply
    end
  end

  defp mediaproc_addr do
    Application.get_env(:philomena, :mediaproc_addr)
  end
end
