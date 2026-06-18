defmodule PhoenixPaas.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhoenixPaasWeb.Telemetry,
      PhoenixPaas.Repo,
      PhoenixPaas.Vault,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:phoenix_paas, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:phoenix_paas, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:phoenix_paas, Oban)},
      {Phoenix.PubSub, name: PhoenixPaas.PubSub},
      # Start a worker by calling: PhoenixPaas.Worker.start_link(arg)
      # {PhoenixPaas.Worker, arg},
      # Start to serve requests, typically the last entry
      PhoenixPaasWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixPaas.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixPaasWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
