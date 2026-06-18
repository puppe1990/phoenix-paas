defmodule PhoenixPaasWeb.DashboardLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.TenancyFixtures

  setup :register_and_log_in_user

  test "redirects when not logged in" do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/")
  end

  test "renders dashboard overview for tenant", %{conn: conn, scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{name: "lightsail-1", host_ip: "100.59.80.29"})

    TenancyFixtures.app_fixture(scope, server, %{
      name: "Trip Planner",
      slug: "trip-planner",
      github_repo: "puppe1990/trip-planner-ia-phx",
      host: "trip.gestaobem.com"
    })

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard")
    assert render(view) =~ "Trip Planner"
  end

  test "does not show other tenant apps", %{conn: conn, scope: scope} do
    other = TenancyFixtures.scope_fixture()
    server = TenancyFixtures.server_fixture(other)

    TenancyFixtures.app_fixture(other, server, %{
      name: "Secret App",
      slug: "secret",
      github_repo: "other/secret",
      host: "secret.example.com"
    })

    {:ok, view, _html} = live(conn, ~p"/")
    refute render(view) =~ "Secret App"
    assert scope.tenant.id != other.tenant.id
  end
end
