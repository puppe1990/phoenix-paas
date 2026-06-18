defmodule PhoenixPaasWeb.AppLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.{Apps, Deployments, Servers}

  setup do
    {:ok, server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    %{server: server}
  end

  test "lists apps", %{conn: conn, server: server} do
    {:ok, _app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    {:ok, view, _html} = live(conn, ~p"/apps")
    assert has_element?(view, "#apps-list")
    assert render(view) =~ "Trip Planner"
    assert render(view) =~ "trip.gestaobem.com"
  end

  test "shows app with deployments and deploy button", %{conn: conn, server: server} do
    {:ok, app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    {:ok, _deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")
    assert has_element?(view, "#deployments")
    assert has_element?(view, "#deploy-button")
    assert has_element?(view, "#deploy-terminal")
    assert render(view) =~ "abc123"
    assert render(view) =~ "Webhook Secret token"

    view |> element("button", "Reveal") |> render_click()
    assert render(view) =~ app.webhook_secret
  end

  test "queues manual deploy", %{conn: conn, server: server} do
    {:ok, app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")

    view |> element("#deploy-button") |> render_click()

    assert_enqueued(worker: PhoenixPaas.Workers.DeployWorker)
    assert render(view) =~ "Deploy queued"
  end
end
