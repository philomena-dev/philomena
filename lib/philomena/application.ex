defmodule Philomena.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    exclude_log_event? = fn event ->
      # Skip DB logs, they are too verbose
      Map.get(event.meta, :application) in [:ecto_sql, :exq]
    end

    :logger.add_primary_filter(
      :sql_logs,
      {fn event, _ -> if(exclude_log_event?.(event), do: :stop, else: :ignore) end, []}
    )

    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      Philomena.Repo,

      # Background queueing system
      Philomena.ExqSupervisor,

      # Mailer
      {Task.Supervisor, name: Philomena.AsyncEmailSupervisor},

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

      # Advert update batching
      Philomena.Adverts.Server,

      # Start the endpoint when the application starts
      PhilomenaWeb.UserFingerprintUpdater,
      PhilomenaWeb.UserIpUpdater,
      PhilomenaWeb.Endpoint
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
