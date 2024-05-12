defmodule Philomena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    locus_key = Application.get_env(:locus, :license_key)

    if locus_key && locus_key != "" do
      :locus.start_loader(:city, {:maxmind, "GeoLite2-City"},
        update_period: 86_400 * 1_000,
        error_retries: [backoff: 3600]
      )

      :locus.start_loader(:asn, {:maxmind, "GeoLite2-ASN"},
        update_period: 86_400 * 1_000,
        error_retries: [backoff: 3600]
      )
    end

    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Philomena.Repo,

      # Background queueing system
      Philomena.ExqSupervisor,

      # Starts a worker by calling: Philomena.Worker.start_link(arg)
      # {Philomena.Worker, arg},
      {Redix, name: :redix, host: Application.get_env(:philomena, :redis_host)},
      {Phoenix.PubSub,
       [
         name: Philomena.PubSub,
         adapter: Phoenix.PubSub.Redis,
         host: Application.get_env(:philomena, :redis_host),
         node_name: valid_node_name(node())
       ]},

      # Start the endpoint when the application starts
      PhilomenaWeb.AdvertUpdater,
      PhilomenaWeb.UserFingerprintUpdater,
      PhilomenaWeb.UserIpUpdater,
      PhilomenaWeb.Endpoint,

      # Connection drainer for SIGTERM
      {Plug.Cowboy.Drainer, refs: [PhilomenaWeb.Endpoint.HTTP]}
    ]

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

  # Redis adapter really really wants you to have a unique node name,
  # so just fake one if iex is being started
  defp valid_node_name(node) when node in [nil, :nonode@nohost],
    do: Base.encode16(:crypto.strong_rand_bytes(6))

  defp valid_node_name(node), do: node
end
