defmodule PhoenixPaas.Deploy.SshRunnerTest do
  use PhoenixPaas.DataCase, async: false

  alias PhoenixPaas.{Apps, Deployments, Servers}
  alias PhoenixPaas.Deploy.SshRunner

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

    {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "manual"})

    %{deployment: deployment}
  end

  test "returns error when SSH key is missing", %{deployment: deployment} do
    assert {:error, "SSH private key not configured on server"} =
             SshRunner.deploy(deployment)
  end
end
