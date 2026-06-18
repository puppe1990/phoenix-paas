defmodule PhoenixPaasWeb.AppLive.Show do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Deployments}

  @poll_ms 1_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    app = Apps.get_app!(scope, id)
    deployments = Deployments.for_app(scope, app)

    socket =
      socket
      |> assign(:page_title, app.name)
      |> assign(:active_tab, :apps)
      |> assign(:browser_path, "apps/#{app.slug}")
      |> assign(:app, app)
      |> assign(:apps, Apps.list_apps(scope))
      |> assign(:deployments, deployments)
      |> assign(:webhook_url, webhook_url())
      |> assign(:show_secret?, false)
      |> assign(:latest_deployment, List.first(deployments))
      |> assign(:deploying?, active_deployment?(deployments))
      |> schedule_poll(active_deployment?(deployments))

    {:ok, socket}
  end

  @impl true
  def handle_event("deploy", _params, socket) do
    case Deployments.enqueue(socket.assigns.current_scope, socket.assigns.app, %{
           git_sha: "manual",
           triggered_by: "manual"
         }) do
      {:ok, _job} ->
        deployments =
          Deployments.for_app(socket.assigns.current_scope, socket.assigns.app)

        {:noreply,
         socket
         |> assign(:deployments, deployments)
         |> assign(:latest_deployment, List.first(deployments))
         |> assign(:deploying?, true)
         |> schedule_poll(true)
         |> put_flash(:info, "Deploy queued")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not queue deploy")}
    end
  end

  def handle_event("toggle_secret", _params, socket) do
    {:noreply, assign(socket, :show_secret?, not socket.assigns.show_secret?)}
  end

  def handle_event("select_app", %{"app_id" => app_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/apps/#{app_id}")}
  end

  @impl true
  def handle_info(:poll_deployments, socket) do
    deployments = Deployments.for_app(socket.assigns.current_scope, socket.assigns.app)
    deploying? = active_deployment?(deployments)

    {:noreply,
     socket
     |> assign(:deployments, deployments)
     |> assign(:latest_deployment, List.first(deployments))
     |> assign(:deploying?, deploying?)
     |> schedule_poll(deploying?)}
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
      <div class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3 border-b border-hd-border/40 pb-3">
          <div class="flex items-center gap-2">
            <span class="font-mono text-[10px] uppercase tracking-wider text-hd-muted">
              Active Application:
            </span>
            <select
              id="app-selector"
              class="paas-select"
              phx-change="select_app"
              name="app_id"
            >
              <option :for={app <- @apps} value={app.id} selected={app.id == @app.id}>
                {app.name} ({app.branch})
              </option>
            </select>
          </div>
          <div class="text-xs text-hd-muted">
            Repository mapping: <span class="font-mono text-hd-orange">{@app.github_repo}</span>
          </div>
        </div>

        <div class="paas-card flex flex-col gap-3 p-4 md:flex-row md:items-center md:justify-between">
          <div class="flex items-center gap-2">
            <span class="inline-flex h-7 w-12 items-center justify-center rounded border border-hd-border bg-hd-aside font-mono text-[10px] font-bold text-hd-orange">
              PHX
            </span>
            <div>
              <h2 class="font-display text-base font-semibold text-hd-text">{@app.name}</h2>
              <p class="flex items-center gap-1 font-mono text-[11px] text-hd-muted">
                <.icon name="hero-code-bracket" class="size-3" />
                {@app.github_repo}
                <span class="text-hd-border">|</span> branch: {@app.branch}
              </p>
            </div>
          </div>

          <button
            id="deploy-button"
            type="button"
            phx-click="deploy"
            disabled={@deploying?}
            class={["paas-btn-primary uppercase", @deploying? && "opacity-50"]}
          >
            <.icon
              name={if @deploying?, do: "hero-arrow-path", else: "hero-play"}
              class={["size-3.5", @deploying? && "motion-safe:animate-spin"]}
            />
            {if @deploying?, do: "Build in progress…", else: "Deploy now"}
          </button>
        </div>

        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <.info_tile label="Domain Host" value={@app.host} mono sub="IPv4 ingress endpoint" />
          <.info_tile label="Deploy Branch" value={@app.branch} mono sub="Git HEAD target" />
          <.info_tile label="Target Server" value={@app.server.host_ip} mono sub={@app.server.name} />
          <.info_tile
            label="Auto Deploy"
            value={if @app.auto_deploy, do: "Webhook Enabled", else: "Manual Selector"}
            sub="HMAC Sha256 keys"
          />
        </div>

        <div class="paas-card space-y-3 p-4">
          <div class="space-y-0.5">
            <h3 class="font-display text-xs font-semibold text-hd-text">
              GitHub Push webhook URL Credentials
            </h3>
            <p class="text-[11px] text-hd-muted">
              Configure these properties on GitHub (Repository Settings → Webhooks) to enable instant automatic deploys on push
            </p>
          </div>
          <div class="grid gap-3 md:grid-cols-2">
            <.copy_field id="webhook-url" label="Payload URL" value={@webhook_url} mono />
            <div class="space-y-1">
              <div class="flex items-center justify-between">
                <span class="font-mono text-[9px] font-semibold uppercase tracking-wider text-hd-muted">
                  Webhook Secret token
                </span>
                <button
                  type="button"
                  phx-click="toggle_secret"
                  class="text-[10px] text-hd-orange hover:underline"
                >
                  {if @show_secret?, do: "Hide", else: "Reveal"}
                </button>
              </div>
              <.copy_field
                :if={@show_secret?}
                id="webhook-secret"
                label=""
                value={@app.webhook_secret}
                mono
              />
              <div
                :if={not @show_secret?}
                id="webhook-secret-masked"
                class="rounded border border-hd-border bg-hd-aside px-2.5 py-1.5 font-mono text-xs text-hd-muted/60"
              >
                {String.duplicate("•", 32)}
              </div>
            </div>
          </div>
        </div>

        <div :if={@latest_deployment} class="space-y-1.5">
          <div class="flex items-center justify-between px-0.5">
            <span class="block font-mono text-[10px] font-semibold uppercase tracking-widest text-hd-muted">
              Build Output Stream logs
            </span>
            <span
              :if={@deploying?}
              class="flex items-center gap-1 font-mono text-[11px] text-hd-orange"
            >
              <span class="size-1 animate-ping rounded-full bg-hd-orange" /> Compiling OTP release…
            </span>
          </div>
          <div :if={@deploying?} class="h-1 overflow-hidden rounded-full bg-hd-aside">
            <div class="deploy-progress h-full rounded-full" />
          </div>
          <.deploy_terminal deployment={@latest_deployment} active?={@deploying?} />
        </div>

        <div class="overflow-hidden rounded-md border border-hd-border bg-hd-card">
          <div class="border-b border-hd-border bg-hd-aside px-4 py-2">
            <span class="font-display text-xs font-semibold text-hd-text">
              Deployments Version History
            </span>
          </div>
          <div id="deployments" class="overflow-x-auto">
            <table class="paas-table w-full text-left font-mono">
              <thead>
                <tr>
                  <th>Build Status</th>
                  <th>Commit/SHA Code</th>
                  <th>Trigger</th>
                  <th>Executed Timestamp</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={@deployments == []}>
                  <td colspan="4" class="py-6 text-center text-xs text-hd-muted">
                    No deployments registered yet. Click "Deploy now" to launch container builds.
                  </td>
                </tr>
                <tr :for={deployment <- @deployments}>
                  <td><.deploy_status_badge status={deployment.status} /></td>
                  <td>
                    <span class="rounded border border-hd-border bg-hd-aside px-1.5 py-0.5 text-[10px] text-hd-orange">
                      {deployment.git_sha}
                    </span>
                  </td>
                  <td class="text-[11px] text-hd-muted">{deployment.triggered_by}</td>
                  <td class="text-[11px] text-hd-muted">
                    {format_datetime(deployment.started_at || deployment.inserted_at)}
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

  defp active_deployment?(deployments) do
    Enum.any?(deployments, &(&1.status in [:queued, :running]))
  end

  defp schedule_poll(socket, true) do
    Process.send_after(self(), :poll_deployments, @poll_ms)
    socket
  end

  defp schedule_poll(socket, false), do: socket

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp webhook_url do
    PhoenixPaasWeb.Endpoint.url() <> "/webhooks/github"
  end
end
