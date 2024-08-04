defmodule PhilomenaJob.NotifierServer do
  @moduledoc """
  Process wrapper to receive notifications from the Postgres LISTEN command.

  A supervision tree example:

      children = [
        {PhilomenaJob.NotifierServer, repo_url: "ecto://postgres@postgres/philomena_dev"}
      ]

  """

  alias Postgrex.Notifications

  @doc false
  def child_spec(opts) do
    url = Keyword.fetch!(opts, :repo_url)
    opts = Ecto.Repo.Supervisor.parse_url(url)

    %{
      id: __MODULE__,
      start: {Notifications, :start_link, [opts]},
      restart: :temporary,
      significant: true
    }
  end

  @doc """
  Begin listening to the given channel. Returns a reference.

  See `Postgrex.Notifications.listen!/3` for more information.
  """
  defdelegate listen!(pid, channel, opts \\ []), to: Notifications

  @doc """
  Stop listening to the channel identified by the given reference.

  See `Postgrex.Notifications.unlisten!/3` for more information.
  """
  defdelegate unlisten!(pid, ref, opts \\ []), to: Notifications
end
