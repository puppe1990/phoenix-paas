defmodule PhoenixPaasWeb.AppLive.Show do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Deployments}
  alias PhoenixPaas.Deploy.RuntimePackages
  alias PhoenixPaasWeb.AppLive.Layout

  @poll_ms 1_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    app = Apps.get_app!(scope, id)
    runtime_packages = RuntimePackages.resolve(app).packages
    custom_domain_app? = app.slug == "catalogo"
    deploying? = active_deployment?(Deployments.for_app(scope, app))

    socket =
      socket
      |> assign(:page_title, app.name)
      |> assign(:active_tab, :apps)
      |> assign(:app, app)
      |> assign(:apps, Apps.list_apps(scope))
      |> assign(:webhook_url, webhook_url())
      |> assign(:show_secret?, false)
      |> assign(:show_env_values?, false)
      |> assign(:env_vars, Apps.list_env_vars_for_display(app))
      |> assign(:env_file, Apps.App.deploy_config(app).env_file)
      |> assign(:runtime_packages, runtime_packages)
      |> assign(:custom_domain_app?, custom_domain_app?)
      |> assign(:detail_tabs, Layout.detail_tabs(custom_domain_app?, runtime_packages))
      |> assign(:app_detail_tab, :environment)
      |> assign(:deploying?, deploying?)
      |> schedule_poll(deploying?)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"id" => _id, "tab" => tab} ->
        {:noreply, assign(socket, :app_detail_tab, Layout.parse_detail_tab(tab))}

      %{"id" => id} ->
        {:noreply, push_navigate(socket, to: ~p"/apps/#{id}/deployments")}
    end
  end

  @impl true
  def handle_event("deploy", _params, socket) do
    case Deployments.enqueue(socket.assigns.current_scope, socket.assigns.app, %{
           git_sha: "manual",
           triggered_by: "manual"
         }) do
      {:ok, _job} ->
        {:noreply,
         socket
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

  def handle_event("select_app", %{"app_id" => app_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/apps/#{app_id}/deployments")}
  end

  @impl true
  def handle_info(:poll_deployments, socket) do
    deploying? =
      active_deployment?(Deployments.for_app(socket.assigns.current_scope, socket.assigns.app))

    {:noreply,
     socket
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
        <Layout.shell_header app={@app} apps={@apps} />
        <Layout.shell_hero app={@app} deploying?={@deploying?} />
        <Layout.shell_info_tiles app={@app} />

        <div id="app-detail-tabs" class="paas-card overflow-hidden">
          <Layout.tab_bar app={@app} active_tab={@app_detail_tab} detail_tabs={@detail_tabs} />

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

  defp webhook_url do
    PhoenixPaasWeb.Endpoint.url() <> "/webhooks/github"
  end
end
