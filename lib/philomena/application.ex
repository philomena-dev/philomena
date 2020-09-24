defmodule Philomena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children =
      default_config()
      |> maybe_endpoint_config(Application.get_env(:philomena, :endpoint))
      |> maybe_worker_config(Application.get_env(:philomena, :worker))

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Philomena.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PhilomenaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp default_config do
    [
      # Start the Ecto repository
      Philomena.Repo,

      # Starts a worker by calling: Philomena.Worker.start_link(arg)
      # {Philomena.Worker, arg},
      Philomena.Servers.Config,
      {Redix, name: :redix, host: Application.get_env(:philomena, :redis_host)}
    ]
  end

  defp maybe_endpoint_config(children, true) do
    children ++
      [
        {Phoenix.PubSub, [name: Philomena.PubSub, adapter: Phoenix.PubSub.PG2]},

        # Start the endpoint when the application starts
        PhilomenaWeb.AdvertUpdater,
        PhilomenaWeb.UserFingerprintUpdater,
        PhilomenaWeb.UserIpUpdater,
        PhilomenaWeb.Endpoint,

        # Connection drainer for SIGTERM
        {RanchConnectionDrainer, ranch_ref: PhilomenaWeb.Endpoint.HTTP, shutdown: 30_000}
      ]
  end

  defp maybe_endpoint_config(children, _false), do: children

  defp maybe_worker_config(children, true) do
    children ++
      [
        # Background queueing system
        Philomena.ExqSupervisor
      ]
  end

  defp maybe_worker_config(children, _false), do: children
end
