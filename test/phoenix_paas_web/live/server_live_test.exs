defmodule PhoenixPaasWeb.ServerLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.Servers
  alias PhoenixPaas.TenancyFixtures

  setup :register_and_log_in_user

  test "lists servers", %{conn: conn, scope: scope} do
    TenancyFixtures.server_fixture(scope, %{name: "lightsail-1", host_ip: "100.59.80.29"})

    {:ok, view, _html} = live(conn, ~p"/servers")
    assert has_element?(view, "#servers-list")
    assert render(view) =~ "lightsail-1"
  end

  test "creates server from form", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/servers/new")

    assert view
           |> form("#server-form",
             server: %{name: "prod", host_ip: "10.0.0.1", region: "us-east-1"}
           )
           |> render_submit()

    assert_redirect(view, ~p"/servers")

    assert [%{name: "prod", host_ip: "10.0.0.1"}] = Servers.list_servers(scope)
  end
end
