defmodule PhoenixPaasWeb.AppLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.Deployments
  alias PhoenixPaas.TenancyFixtures

  setup :register_and_log_in_user

  setup %{scope: scope} do
    server = TenancyFixtures.server_fixture(scope)
    %{server: server}
  end

  test "lists apps", %{conn: conn, scope: scope, server: server} do
    TenancyFixtures.app_fixture(scope, server, %{
      name: "Trip Planner",
      slug: "trip-planner",
      github_repo: "puppe1990/trip-planner-ia-phx",
      host: "trip.gestaobem.com"
    })

    {:ok, view, _html} = live(conn, ~p"/apps")
    assert has_element?(view, "#apps-list")
    assert render(view) =~ "Trip Planner"
  end

  test "shows app with deployments and deploy button", %{conn: conn, scope: scope, server: server} do
    app =
      TenancyFixtures.app_fixture(scope, server, %{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com"
      })

    {:ok, _deployment} = Deployments.create_deployment(app, %{git_sha: "abc123"})

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")
    assert has_element?(view, "#deploy-button")
    assert render(view) =~ "abc123"
  end

  test "queues manual deploy", %{conn: conn, scope: scope, server: server} do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")
    view |> element("#deploy-button") |> render_click()

    assert_enqueued(worker: PhoenixPaas.Workers.DeployWorker)
    assert render(view) =~ "Deploy queued"
  end
end
