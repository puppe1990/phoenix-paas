defmodule PhoenixPaasWeb.AppLive.Show do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Deployments}
  alias PhoenixPaas.Deploy.RuntimePackages

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
      |> assign(:app, app)
      |> assign(:apps, Apps.list_apps(scope))
      |> assign(:deployments, deployments)
      |> assign(:webhook_url, webhook_url())
      |> assign(:show_secret?, false)
      |> assign(:show_env_values?, false)
      |> assign(:env_vars, Apps.list_env_vars_for_display(app))
      |> assign(:env_file, Apps.App.deploy_config(app).env_file)
      |> assign(:selected_deployment_id, nil)
      |> assign(
        :viewed_deployment,
        viewed_deployment(deployments, nil, active_deployment?(deployments))
      )
      |> assign(:deploying?, active_deployment?(deployments))
      |> assign(:runtime_packages, RuntimePackages.resolve(app).packages)
      |> assign(:custom_domain_app?, app.slug == "catalogo")
      |> then(fn socket ->
        runtime_packages = socket.assigns.runtime_packages
        custom_domain_app? = socket.assigns.custom_domain_app?

        socket
        |> assign(:detail_tabs, detail_tabs(custom_domain_app?, runtime_packages))
        |> assign(:app_detail_tab, default_app_detail_tab(custom_domain_app?, runtime_packages))
      end)
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
         |> assign(:selected_deployment_id, nil)
         |> assign(:viewed_deployment, viewed_deployment(deployments, nil, true))
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

  def handle_event("toggle_env_values", _params, socket) do
    {:noreply, assign(socket, :show_env_values?, not socket.assigns.show_env_values?)}
  end

  def handle_event("select_app_detail_tab", %{"tab" => tab}, socket) do
    case Enum.find(socket.assigns.detail_tabs, &(Atom.to_string(&1) == tab)) do
      nil -> {:noreply, socket}
      tab -> {:noreply, assign(socket, :app_detail_tab, tab)}
    end
  end

  def handle_event("select_app", %{"app_id" => app_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/apps/#{app_id}")}
  end

  def handle_event("view_deploy_log", %{"id" => id}, socket) do
    if socket.assigns.deploying? do
      {:noreply, socket}
    else
      deployment_id = String.to_integer(id)

      {:noreply,
       socket
       |> assign(:selected_deployment_id, deployment_id)
       |> assign(
         :viewed_deployment,
         viewed_deployment(socket.assigns.deployments, deployment_id, false)
       )}
    end
  end

  @impl true
  def handle_info(:poll_deployments, socket) do
    deployments = Deployments.for_app(socket.assigns.current_scope, socket.assigns.app)
    deploying? = active_deployment?(deployments)
    selected_id = if deploying?, do: nil, else: socket.assigns.selected_deployment_id

    {:noreply,
     socket
     |> assign(:deployments, deployments)
     |> assign(:selected_deployment_id, selected_id)
     |> assign(:viewed_deployment, viewed_deployment(deployments, selected_id, deploying?))
     |> assign(:deploying?, deploying?)
     |> schedule_poll(deploying?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      active_tab={@active_tab}
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

        <div id="app-detail-tabs" class="paas-card overflow-hidden">
          <div
            role="tablist"
            aria-label="App configuration"
            class="flex flex-wrap items-center gap-1 border-b border-hd-border bg-hd-aside p-1"
          >
            <.detail_tab_button
              :if={:domains in @detail_tabs}
              tab={:domains}
              label="Tenant domains"
              icon="hero-globe-alt"
              active?={@app_detail_tab == :domains}
            />
            <.detail_tab_button
              tab={:environment}
              label="Environment"
              icon="hero-circle-stack"
              active?={@app_detail_tab == :environment}
            />
            <.detail_tab_button
              :if={:runtime in @detail_tabs}
              tab={:runtime}
              label="Runtime"
              icon="hero-cube"
              active?={@app_detail_tab == :runtime}
            />
            <.detail_tab_button
              tab={:webhook}
              label="Webhook"
              icon="hero-link"
              active?={@app_detail_tab == :webhook}
            />
            <.detail_tab_button
              tab={:deployments}
              label="Deployments"
              icon="hero-rocket-launch"
              active?={@app_detail_tab == :deployments}
            />
          </div>

          <div class="p-4">
            <div :if={@app_detail_tab == :domains} id="custom-domain-checklist" class="space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h3 class="font-display text-xs font-semibold text-hd-text">Custom tenant domains</h3>
                <span class="rounded border border-hd-orange/40 bg-hd-orange/10 px-2 py-0.5 font-mono text-[9px] text-hd-orange">
                  Solo server · on-demand TLS
                </span>
              </div>
              <p class="text-[11px] leading-relaxed text-hd-muted">
                Tenants point a <span class="font-mono text-hd-text">CNAME</span>
                to <span class="font-mono text-hd-orange">DOMAIN_CNAME_TARGET</span>
                (set to {@app.host}), then verify DNS in the admin panel.
                Caddy issues certificates only after the tenant domain is verified.
              </p>
              <ul class="space-y-1 font-mono text-[10px] text-hd-muted">
                <li>
                  <span class="text-hd-orange">PLATFORM_HOSTS</span>
                  — platform hostnames served directly
                </li>
                <li>
                  <span class="text-hd-orange">DOMAIN_CNAME_TARGET</span>
                  — CNAME anchor for tenant custom domains
                </li>
                <li>
                  <span class="text-hd-orange">PHX_HOST</span> — primary platform host ({@app.host})
                </li>
              </ul>
            </div>

            <div :if={@app_detail_tab == :environment} id="app-env-vars" class="space-y-3">
              <div class="flex items-start justify-between gap-3">
                <div class="space-y-0.5">
                  <h3 class="font-display text-xs font-semibold text-hd-text">
                    Environment variables
                  </h3>
                  <p class="text-[11px] text-hd-muted">
                    Synced to <span class="font-mono text-hd-orange">{@env_file}</span>
                    on every deploy. <span class="text-hd-text">PHX_HOST</span>
                    is always injected from the app host ({@app.host}).
                  </p>
                </div>
                <button
                  :if={Enum.any?(@env_vars, & &1.sensitive?)}
                  type="button"
                  phx-click="toggle_env_values"
                  class="shrink-0 text-[10px] text-hd-orange hover:underline"
                >
                  {if @show_env_values?, do: "Hide secrets", else: "Reveal secrets"}
                </button>
              </div>

              <div
                :if={@env_vars == []}
                class="rounded border border-dashed border-hd-border px-4 py-6 text-center text-xs text-hd-muted"
              >
                No environment variables configured yet.
              </div>

              <div :if={@env_vars != []} class="overflow-hidden rounded border border-hd-border">
                <table class="paas-table w-full text-left font-mono">
                  <thead>
                    <tr>
                      <th>Key</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody id="env-vars-list">
                    <tr :for={env_var <- @env_vars} id={"env-var-#{env_var.key}"}>
                      <td class="align-top text-[11px] text-hd-orange">{env_var.key}</td>
                      <td class="max-w-0">
                        <span class="block truncate text-[11px] text-hd-text">
                          {Apps.display_env_value(env_var.key, env_var.value, @show_env_values?)}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div :if={@app_detail_tab == :runtime} id="runtime-packages" class="space-y-3">
              <div class="space-y-0.5">
                <h3 class="font-display text-xs font-semibold text-hd-text">Runtime packages</h3>
                <p class="text-[11px] text-hd-muted">
                  Installed automatically on every deploy via apt.
                </p>
              </div>
              <div class="flex flex-wrap gap-2">
                <span
                  :for={package <- @runtime_packages}
                  class="rounded border border-hd-border bg-hd-aside px-2 py-0.5 font-mono text-[10px] text-hd-orange"
                >
                  {package}
                </span>
              </div>
            </div>

            <div :if={@app_detail_tab == :webhook} id="app-webhook" class="space-y-3">
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

            <div :if={@app_detail_tab == :deployments} id="app-deployments" class="space-y-4">
              <div :if={@viewed_deployment} class="space-y-1.5">
                <div class="flex flex-wrap items-center justify-between gap-2 px-0.5">
                  <div class="space-y-0.5">
                    <span class="block font-mono text-[10px] font-semibold uppercase tracking-widest text-hd-muted">
                      Build Output Stream logs
                    </span>
                    <span
                      :if={@selected_deployment_id && @viewed_deployment}
                      class="font-mono text-[10px] text-hd-muted"
                    >
                      Viewing deploy #{@viewed_deployment.id} · click another row in history to switch
                    </span>
                  </div>
                  <div class="flex flex-wrap items-center gap-3">
                    <span
                      :if={Deployments.duration(@viewed_deployment)}
                      class="font-mono text-[11px] tabular-nums text-hd-text"
                    >
                      Duration: {Deployments.format_duration(Deployments.duration(@viewed_deployment))}
                    </span>
                    <span
                      :if={@deploying?}
                      class="flex items-center gap-1 font-mono text-[11px] text-hd-orange"
                    >
                      <span class="size-1 animate-ping rounded-full bg-hd-orange" />
                      Compiling OTP release…
                    </span>
                  </div>
                </div>
                <div :if={@deploying?} class="h-1 overflow-hidden rounded-full bg-hd-aside">
                  <div class="deploy-progress h-full rounded-full" />
                </div>
                <.deploy_terminal
                  id={"deploy-terminal-#{@viewed_deployment.id}"}
                  deployment={@viewed_deployment}
                  active?={@deploying?}
                  duration={Deployments.format_duration(Deployments.duration(@viewed_deployment))}
                />
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
                        <th>Duration</th>
                        <th>Executed Timestamp</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :if={@deployments == []}>
                        <td colspan="6" class="py-6 text-center text-xs text-hd-muted">
                          No deployments registered yet. Click "Deploy now" to launch container builds.
                        </td>
                      </tr>
                      <tr
                        :for={deployment <- @deployments}
                        id={"deployment-row-#{deployment.id}"}
                        class={[
                          "transition-colors",
                          @viewed_deployment && @viewed_deployment.id == deployment.id &&
                            "bg-hd-aside/60"
                        ]}
                      >
                        <td><.deploy_status_badge status={deployment.status} /></td>
                        <td>
                          <span class="rounded border border-hd-border bg-hd-aside px-1.5 py-0.5 text-[10px] text-hd-orange">
                            {deployment.git_sha}
                          </span>
                        </td>
                        <td class="text-[11px] text-hd-muted">{deployment.triggered_by}</td>
                        <td class="text-[11px] tabular-nums text-hd-text">
                          {Deployments.format_duration(Deployments.duration(deployment))}
                        </td>
                        <td class="text-[11px] text-hd-muted">
                          {format_datetime(deployment.started_at || deployment.inserted_at)}
                        </td>
                        <td class="text-right">
                          <button
                            :if={not @deploying?}
                            id={"view-deploy-log-#{deployment.id}"}
                            type="button"
                            phx-click="view_deploy_log"
                            phx-value-id={deployment.id}
                            class={[
                              "rounded border px-2 py-0.5 font-mono text-[10px] transition-colors",
                              @viewed_deployment && @viewed_deployment.id == deployment.id &&
                                "border-hd-orange/50 bg-hd-orange/10 text-hd-orange",
                              (!@viewed_deployment || @viewed_deployment.id != deployment.id) &&
                                "border-hd-border text-hd-muted hover:border-hd-orange/40 hover:text-hd-orange"
                            ]}
                          >
                            View log
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :tab, :atom, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active?, :boolean, required: true

  defp detail_tab_button(assigns) do
    ~H"""
    <button
      id={"app-detail-tab-#{@tab}"}
      type="button"
      role="tab"
      aria-selected={@active?}
      phx-click="select_app_detail_tab"
      phx-value-tab={Atom.to_string(@tab)}
      class={[
        "flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-semibold tracking-wide transition-all",
        @active? && "border border-hd-border bg-hd-card text-hd-orange",
        !@active? && "text-hd-muted hover:text-hd-text"
      ]}
    >
      <.icon name={@icon} class="size-3.5" />
      <span>{@label}</span>
    </button>
    """
  end

  defp detail_tabs(custom_domain_app?, runtime_packages) do
    []
    |> then(fn tabs -> if custom_domain_app?, do: [:domains | tabs], else: tabs end)
    |> Kernel.++([:environment])
    |> then(fn tabs -> if runtime_packages != [], do: tabs ++ [:runtime], else: tabs end)
    |> Kernel.++([:webhook, :deployments])
  end

  defp default_app_detail_tab(custom_domain_app?, runtime_packages) do
    detail_tabs(custom_domain_app?, runtime_packages) |> List.first()
  end

  defp active_deployment?(deployments) do
    Enum.any?(deployments, &(&1.status in [:queued, :running]))
  end

  defp viewed_deployment(deployments, selected_id, deploying?) do
    cond do
      deploying? ->
        Enum.find(deployments, &(&1.status in [:queued, :running])) || List.first(deployments)

      selected_id ->
        Enum.find(deployments, &(&1.id == selected_id)) || List.first(deployments)

      true ->
        List.first(deployments)
    end
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
