defmodule PhoenixPaasWeb.DashboardLive do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Servers}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    servers = Servers.list_servers(scope)
    apps = Apps.list_apps(scope)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       active_tab: :dashboard,
       browser_path: "dashboard",
       servers: servers,
       apps: apps,
       server_count: length(servers),
       app_count: length(apps)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active_tab={@active_tab}
      browser_path={@browser_path}
      server_count={@server_count}
      app_count={@app_count}
    >
      <div id="dashboard" class="space-y-4">
        <div class="relative overflow-hidden rounded-md border border-hd-border bg-hd-card p-5">
          <.icon
            name="hero-fire"
            class="pointer-events-none absolute -right-4 -top-4 size-48 rotate-12 fill-current text-hd-orange/5"
          />
          <div class="relative z-10 max-w-2xl space-y-2">
            <span class="inline-block rounded border border-hd-border bg-hd-aside px-2 py-0.5 font-mono text-[9px] font-bold uppercase tracking-widest text-hd-orange">
              AWS LIGHTSAIL AUTOMATIC DISPATCH
            </span>
            <h2 class="font-display text-2xl font-semibold tracking-tight text-hd-text">
              Phoenix PaaS
            </h2>
            <p class="font-sans text-xs leading-relaxed text-hd-muted">
              Deploy production-ready Phoenix and Elixir applications directly to your AWS Lightsail virtual machines
              with bare-metal OTP performance. Leverage git webhooks triggers to rebuild releases instantly on commit
              push events, completely isolated without the overhead of Kubernetes.
            </p>
            <div class="flex flex-wrap items-center gap-2 pt-1">
              <span class="flex items-center gap-1 rounded border border-hd-border bg-hd-bg px-2 py-0.5 text-[11px] text-hd-muted">
                <.icon name="hero-check-circle" class="size-3.5 text-hd-green" />
                No Kubernetes Overheads
              </span>
              <span class="flex items-center gap-1 rounded border border-hd-border bg-hd-bg px-2 py-0.5 text-[11px] text-hd-muted">
                <.icon name="hero-check-circle" class="size-3.5 text-hd-green" />
                Direct Monit releases
              </span>
              <span class="flex items-center gap-1 rounded border border-hd-border bg-hd-bg px-2 py-0.5 text-[11px] text-hd-muted">
                <.icon name="hero-check-circle" class="size-3.5 text-hd-green" />
                GitHub Payload SSL Encryption
              </span>
            </div>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <.link navigate={~p"/servers"} class="block">
            <.metric_card
              title="Registered Lightsail VMs"
              value={Integer.to_string(@server_count)}
              hint="Active Hypervisors"
              icon="hero-server-stack"
            />
          </.link>

          <.link navigate={~p"/apps"} class="block">
            <.metric_card
              title="Configured Elixir Apps"
              value={Integer.to_string(@app_count)}
              hint="Live Routes"
              icon="hero-globe-alt"
            />
          </.link>
        </div>

        <div class="overflow-hidden rounded-md border border-hd-border bg-hd-card">
          <div class="flex items-center justify-between border-b border-hd-border bg-hd-aside px-4 py-2.5">
            <div class="space-y-0.5">
              <h3 class="font-display text-xs font-semibold text-hd-text">
                Registered Phoenix Applications
              </h3>
              <p class="text-[11px] text-hd-muted">
                Live directory list mapping GitHub repositories to AWS systemd processes
              </p>
            </div>
            <.link
              navigate={~p"/apps/new"}
              class="flex items-center gap-1 font-mono text-xs font-bold text-hd-orange hover:text-hd-orange-dark"
            >
              <.icon name="hero-plus" class="size-3.5" /> Register App
            </.link>
          </div>

          <div :if={@apps == []} class="space-y-3 p-6 text-center">
            <div class="mx-auto flex size-10 items-center justify-center rounded-md border border-hd-border bg-hd-aside text-hd-muted">
              <.icon name="hero-globe-alt" class="size-5" />
            </div>
            <div class="space-y-0.5">
              <h4 class="text-xs font-medium text-hd-text">No applications configured</h4>
              <p class="mx-auto max-w-sm text-[11px] text-hd-muted">
                Configure your first application repository, assign target domain hosts, and copy payload webhooks secret tokens.
              </p>
            </div>
            <.link navigate={~p"/apps/new"} class="paas-btn-primary mx-auto">
              <.icon name="hero-plus" class="size-3.5" /> Register App
            </.link>
          </div>

          <div :if={@apps != []} class="overflow-x-auto">
            <table class="paas-table w-full text-left">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Host</th>
                  <th>Server</th>
                  <th class="text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={app <- @apps}>
                  <td>
                    <.link
                      navigate={~p"/apps/#{app.id}"}
                      class="font-medium text-hd-orange hover:text-hd-orange-dark"
                    >
                      {app.name}
                    </.link>
                  </td>
                  <td class="font-mono text-sm">{app.host}</td>
                  <td>{app.server.name}</td>
                  <td class="text-right">
                    <.link navigate={~p"/apps/#{app.id}"} class="paas-btn-secondary text-[10px]">
                      <.icon name="hero-rocket-launch" class="size-3" /> Deploy
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
