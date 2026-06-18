defmodule PhoenixPaas.Workers.DeployWorkerTest do
  use PhoenixPaas.DataCase, async: false

  import Mox

  use Oban.Testing,
    repo: PhoenixPaas.Repo,
    notifier: Oban.Notifiers.Isolated,
    testing: :manual

  alias PhoenixPaas.{Apps, Deployments, Servers, Workers.DeployWorker}
  alias PhoenixPaas.Deploy.RunnerMock

  setup :verify_on_exit!

  setup do
    {:ok, server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    {:ok, app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    %{app: app}
  end

  test "marks deployment successful when runner succeeds", %{app: app} do
    expect(RunnerMock, :deploy, fn deployment ->
      assert deployment.status == :running
      {:ok, "deploy ok"}
    end)

    {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})
    assert :ok = perform_job(DeployWorker, %{"deployment_id" => deployment.id})

    deployment = Deployments.for_app(app) |> List.first()
    assert deployment.status == :success
    assert deployment.log =~ "deploy ok"
  end

  test "marks deployment failed when runner errors", %{app: app} do
    expect(RunnerMock, :deploy, fn _deployment -> {:error, "ssh failed"} end)

    {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})
    assert {:error, "ssh failed"} = perform_job(DeployWorker, %{"deployment_id" => deployment.id})

    deployment = Deployments.for_app(app) |> List.first()
    assert deployment.status == :failed
    assert deployment.log =~ "ssh failed"
  end
end
