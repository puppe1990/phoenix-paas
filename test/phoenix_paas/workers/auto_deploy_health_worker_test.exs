defmodule PhoenixPaas.Workers.AutoDeployHealthWorkerTest do
  use PhoenixPaas.DataCase, async: false

  import Mox

  use Oban.Testing,
    repo: PhoenixPaas.Repo,
    notifier: Oban.Notifiers.Isolated,
    testing: :manual

  alias PhoenixPaas.TenancyFixtures
  alias PhoenixPaas.Workers.AutoDeployHealthWorker

  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:phoenix_paas, :dns_resolver)
    Application.put_env(:phoenix_paas, :dns_resolver, PhoenixPaas.Deploy.DnsMock)

    on_exit(fn ->
      if previous do
        Application.put_env(:phoenix_paas, :dns_resolver, previous)
      else
        Application.delete_env(:phoenix_paas, :dns_resolver)
      end
    end)

    :ok
  end

  test "does not set Oban unique options that Turso cannot parse" do
    opts = AutoDeployHealthWorker.__opts__()
    refute Keyword.get(opts, :unique)
  end

  test "reconciles stale server IPs from app DNS and succeeds without GitHub token" do
    scope = TenancyFixtures.scope_fixture()

    server =
      TenancyFixtures.server_fixture(scope, %{name: "campanha-lightsail", host_ip: "52.0.157.89"})

    TenancyFixtures.app_fixture(scope, server, %{
      slug: "campanha",
      host: "campanha.gestaobem.com",
      github_repo: "puppe1990/campanha-ops-#{System.unique_integer()}"
    })

    stub(PhoenixPaas.Deploy.DnsMock, :lookup_a, fn "campanha.gestaobem.com" ->
      {:ok, ["52.73.89.19"]}
    end)

    assert :ok = perform_job(AutoDeployHealthWorker, %{})

    reloaded = PhoenixPaas.Servers.get_server!(scope, server.id)
    assert reloaded.host_ip == "52.73.89.19"
  end
end
