defmodule PhoenixPaas.DeploymentsTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.{Apps, Deployments, Servers}

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

  describe "create_deployment/2" do
    test "starts in queued status", %{app: app} do
      assert {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})
      assert deployment.status == :queued
      assert deployment.git_sha == "abc123"
      assert deployment.triggered_by == "manual"
    end
  end

  describe "status transitions" do
    setup %{app: app} do
      {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})
      %{deployment: deployment}
    end

    test "mark_running/1 from queued", %{deployment: deployment} do
      assert {:ok, running} = Deployments.mark_running(deployment)
      assert running.status == :running
      assert running.started_at
    end

    test "mark_success/1 sets finished_at", %{deployment: deployment} do
      {:ok, running} = Deployments.mark_running(deployment)

      assert {:ok, success} = Deployments.mark_success(running, "deploy ok")
      assert success.status == :success
      assert success.finished_at
      assert success.log =~ "deploy ok"
    end

    test "mark_failed/1 appends log", %{deployment: deployment} do
      {:ok, running} = Deployments.mark_running(deployment)

      assert {:ok, failed} = Deployments.mark_failed(running, "boom")
      assert failed.status == :failed
      assert failed.log =~ "boom"
    end

    test "mark_running/1 rejects non-queued", %{deployment: deployment} do
      {:ok, _} = Deployments.mark_running(deployment)
      assert {:error, :invalid_status} = Deployments.mark_running(deployment)
    end
  end

  describe "for_app/1" do
    test "orders by newest first", %{app: app} do
      {:ok, older} = Deployments.create_deployment(app, %{git_sha: "old"})
      {:ok, newer} = Deployments.create_deployment(app, %{git_sha: "new"})

      ids = Enum.map(Deployments.for_app(app), & &1.id)
      assert ids == [newer.id, older.id]
    end
  end
end
