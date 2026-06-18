defmodule PhoenixPaasWeb.ServerLiveTest do
  use PhoenixPaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PhoenixPaas.Servers

  test "lists servers", %{conn: conn} do
    {:ok, _server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    {:ok, view, _html} = live(conn, ~p"/servers")
    assert has_element?(view, "#servers-list")
    assert render(view) =~ "lightsail-1"
    assert render(view) =~ "100.59.80.29"
  end

  test "creates server from form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/servers/new")

    assert view
           |> form("#server-form",
             server: %{name: "prod", host_ip: "10.0.0.1", region: "us-east-1"}
           )
           |> render_submit()

    assert_redirect(view, ~p"/servers")

    assert [%{name: "prod", host_ip: "10.0.0.1"}] = Servers.list_servers()
  end
end
