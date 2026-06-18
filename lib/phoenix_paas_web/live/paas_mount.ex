defmodule PhoenixPaasWeb.PaasMount do
  @moduledoc false
  import Phoenix.Component

  alias PhoenixPaas.{Apps, Servers}

  def on_mount(:default, _params, _session, socket) do
    scope = socket.assigns.current_scope
    servers = Servers.list_servers(scope)
    apps = Apps.list_apps(scope)

    {:cont,
     socket
     |> assign(:server_count, length(servers))
     |> assign(:app_count, length(apps))}
  end
end
