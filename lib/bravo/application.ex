defmodule Bravo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BravoWeb.Telemetry,
      Bravo.Repo,
      {DNSCluster, query: Application.get_env(:bravo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bravo.PubSub},
      {Oban, Application.fetch_env!(:bravo, Oban)},
      Supervisor.child_spec({Cachex, name: :credit_requests_cache}, id: :credit_requests_cache),
      Supervisor.child_spec({Cachex, name: :workflow_cache}, id: :workflow_cache),
      Bravo.Infrastructure.Events.Listener,
      # Start a worker by calling: Bravo.Worker.start_link(arg)
      # {Bravo.Worker, arg},
      # Start to serve requests, typically the last entry
      BravoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bravo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BravoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
