defmodule PhoenixPaasWeb.DashboardLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.{Apps, Servers}

  test "renders dashboard overview", %{conn: conn} do
    {:ok, server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    {:ok, _app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard")
    assert render(view) =~ "Phoenix PaaS"
    assert render(view) =~ "Active Hypervisors"
    assert render(view) =~ "Live Routes"
    assert render(view) =~ "Trip Planner"
  end
end
