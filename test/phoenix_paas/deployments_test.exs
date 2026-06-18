defmodule PhoenixPaas.DeploymentsTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.{Apps, Deployments}
  alias PhoenixPaas.TenancyFixtures

  setup do
    scope = TenancyFixtures.scope_fixture()
    server = TenancyFixtures.server_fixture(scope)

    {:ok, app} =
      Apps.create_app(scope, %{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    %{scope: scope, app: app}
  end

  describe "create_deployment/2" do
    test "starts in queued status", %{app: app} do
      assert {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})
      assert deployment.status == :queued
    end
  end

  describe "enqueue/3" do
    test "rejects cross-tenant app", %{app: app} do
      other_scope = TenancyFixtures.scope_fixture()
      assert {:error, :unauthorized} = Deployments.enqueue(other_scope, app, %{git_sha: "abc"})
    end

    test "queues for scoped app", %{scope: scope, app: app} do
      assert {:ok, _job} = Deployments.enqueue(scope, app, %{git_sha: "abc123"})
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
    end

    test "mark_success/1 sets finished_at", %{deployment: deployment} do
      {:ok, running} = Deployments.mark_running(deployment)
      assert {:ok, success} = Deployments.mark_success(running, "deploy ok")
      assert success.status == :success
    end

    test "mark_failed/1 appends log", %{deployment: deployment} do
      {:ok, running} = Deployments.mark_running(deployment)
      assert {:ok, failed} = Deployments.mark_failed(running, "boom")
      assert failed.log =~ "boom"
    end
  end

  describe "for_app/2" do
    test "orders by newest first", %{scope: scope, app: app} do
      {:ok, older} = Deployments.create_deployment(app, %{git_sha: "old"})
      {:ok, newer} = Deployments.create_deployment(app, %{git_sha: "new"})

      ids = Enum.map(Deployments.for_app(scope, app), & &1.id)
      assert ids == [newer.id, older.id]
    end
  end
end
