defmodule PhoenixPaasWeb.AppLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.{Apps, Deployments}
  alias PhoenixPaas.TenancyFixtures

  setup :register_and_log_in_user

  setup %{scope: scope} do
    server = TenancyFixtures.server_fixture(scope)
    %{server: server}
  end

  test "renders new app form", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/apps/new")

    assert has_element?(view, "#app-form")
    assert html =~ "Register Phoenix Application"
    assert html =~ "Systemd unit"
    assert html =~ "Release path"
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
    assert has_element?(view, "#app-detail-tabs")

    view |> element("#app-detail-tab-deployments") |> render_click()
    assert render(view) =~ "abc123"
  end

  test "switches app detail tabs", %{conn: conn, scope: scope, server: server} do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, view, html} = live(conn, ~p"/apps/#{app.id}")

    assert has_element?(view, "#app-detail-tab-environment")
    assert html =~ "Environment variables"
    refute has_element?(view, "#app-webhook")

    view |> element("#app-detail-tab-webhook") |> render_click()
    assert has_element?(view, "#app-webhook")
    refute has_element?(view, "#app-env-vars")
  end

  test "shows environment variables with masked secrets", %{
    conn: conn,
    scope: scope,
    server: server
  } do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, _} = Apps.put_env_var(app, "PORT", "4003")
    {:ok, _} = Apps.put_env_var(app, "SECRET_KEY_BASE", "super-secret")

    {:ok, view, html} = live(conn, ~p"/apps/#{app.id}")

    assert html =~ "Environment variables"
    assert has_element?(view, "#app-env-vars")
    assert has_element?(view, "#env-var-PORT")
    assert has_element?(view, "#env-var-SECRET_KEY_BASE")
    assert html =~ "4003"
    refute html =~ "super-secret"

    view |> element("button", "Reveal secrets") |> render_click()
    assert render(view) =~ "super-secret"
  end

  test "queues manual deploy", %{conn: conn, scope: scope, server: server} do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")
    view |> element("#deploy-button") |> render_click()

    assert_enqueued(worker: PhoenixPaas.Workers.DeployWorker)
    assert render(view) =~ "Deploy queued"
  end

  test "shows deploy duration in history", %{conn: conn, scope: scope, server: server} do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, deployment} = Deployments.create_deployment(app, %{git_sha: "dur123"})

    {:ok, finished} =
      deployment
      |> Ecto.Changeset.change(%{
        status: :success,
        started_at: ~U[2026-06-29 10:00:00Z],
        finished_at: ~U[2026-06-29 10:01:30Z]
      })
      |> PhoenixPaas.Repo.update()

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")

    view |> element("#app-detail-tab-deployments") |> render_click()
    html = render(view)

    assert html =~ "1m 30s"
    assert has_element?(view, "#deployment-row-#{finished.id}")
  end

  test "views log from an older deployment", %{conn: conn, scope: scope, server: server} do
    app = TenancyFixtures.app_fixture(scope, server)

    {:ok, older} =
      Deployments.create_deployment(app, %{
        git_sha: "older-sha",
        log: "older deploy log line"
      })

    {:ok, older} =
      older
      |> Ecto.Changeset.change(%{
        status: :success,
        started_at: ~U[2026-06-29 09:00:00Z],
        finished_at: ~U[2026-06-29 09:01:00Z]
      })
      |> PhoenixPaas.Repo.update()

    {:ok, newer} =
      Deployments.create_deployment(app, %{
        git_sha: "newer-sha",
        log: "newer deploy log line"
      })

    {:ok, newer} =
      newer
      |> Ecto.Changeset.change(%{
        status: :success,
        started_at: ~U[2026-06-29 10:00:00Z],
        finished_at: ~U[2026-06-29 10:02:00Z]
      })
      |> PhoenixPaas.Repo.update()

    {:ok, view, _html} = live(conn, ~p"/apps/#{app.id}")

    view |> element("#app-detail-tab-deployments") |> render_click()
    html = render(view)

    assert html =~ "newer deploy log line"
    refute html =~ "older deploy log line"

    view |> element("#view-deploy-log-#{older.id}") |> render_click()

    html = render(view)
    assert html =~ "older deploy log line"
    assert has_element?(view, "#deploy-terminal-#{older.id}")
    refute has_element?(view, "#deploy-terminal-#{newer.id}")
  end
end
