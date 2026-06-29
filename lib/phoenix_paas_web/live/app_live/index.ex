defmodule PhoenixPaasWeb.AppLive.Index do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Github, Servers}
  alias PhoenixPaas.Apps.{App, Provisioning}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Apps")
     |> assign(:active_tab, :apps)
     |> assign(:servers, Servers.list_servers(socket.assigns.current_scope))
     |> stream(:apps, Apps.list_apps(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    repos = Github.list_repos()

    socket
    |> assign(:page_title, "New app")
    |> assign(:app, %App{})
    |> assign(:github_repos, repos)
    |> assign(:show_advanced?, false)
    |> assign(:form, to_form(Apps.change_app(%App{})))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Apps")
    |> assign(:app, nil)
    |> assign(:form, nil)
    |> assign(:github_repos, [])
    |> assign(:show_advanced?, false)
  end

  @impl true
  def handle_event("validate", %{"app" => app_params}, socket) do
    app_params =
      app_params
      |> maybe_put_advanced(socket.assigns.show_advanced?)
      |> then(&Provisioning.apply_preset(&1, socket.assigns.servers))

    show_advanced? = advanced_enabled?(app_params, socket.assigns.show_advanced?)

    changeset =
      %App{}
      |> Apps.change_app(app_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:show_advanced?, show_advanced?)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced?, not socket.assigns.show_advanced?)}
  end

  def handle_event("save", %{"app" => app_params}, socket) do
    app_params =
      app_params
      |> maybe_put_advanced(socket.assigns.show_advanced?)
      |> then(&Provisioning.apply_preset(&1, socket.assigns.servers))

    case Apps.create_app(socket.assigns.current_scope, app_params) do
      {:ok, app, webhook_status} ->
        app = Apps.get_app!(socket.assigns.current_scope, app.id)

        {:noreply,
         socket
         |> stream_insert(:apps, app)
         |> assign(:app_count, socket.assigns.app_count + 1)
         |> put_flash(:info, app_registered_message(webhook_status))
         |> push_navigate(to: ~p"/apps/#{app.id}/deployments")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
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
        <div
          :if={@servers == []}
          class="flex items-center gap-3 rounded-md border border-hd-orange/30 bg-hd-card px-4 py-3 text-sm text-hd-orange"
        >
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>Add a server before registering an app.</span>
        </div>

        <div :if={@live_action == :new} class="paas-card">
          <div class="space-y-4 p-4">
            <div class="space-y-1">
              <h3 class="font-display text-sm font-semibold text-hd-text">
                Register Phoenix Application
              </h3>
              <p class="text-xs text-hd-muted">
                Pick a GitHub repository — name, host, deploy paths, and webhook are filled in automatically.
              </p>
            </div>

            <.form for={@form} id="app-form" phx-change="validate" phx-submit="save" class="space-y-4">
              <.input
                :if={@github_repos == []}
                field={@form[:github_repo]}
                type="text"
                label="GitHub repo (owner/name)"
                placeholder="puppe1990/my-phoenix-app"
                required
              />
              <.input
                :if={@github_repos != []}
                field={@form[:github_repo]}
                type="select"
                label="GitHub repository"
                prompt="Choose a repository"
                options={@github_repos}
                required
              />

              <div
                :if={repo_selected?(@form)}
                id="app-provision-preview"
                class="rounded-md border border-hd-border bg-hd-aside p-3"
              >
                <p class="font-mono text-[10px] font-semibold uppercase tracking-wider text-hd-muted">
                  Auto-configured profile
                </p>
                <dl class="mt-2 grid gap-2 sm:grid-cols-2">
                  <.preview_item label="Name" value={@form[:name].value} />
                  <.preview_item label="Slug" value={@form[:slug].value} mono />
                  <.preview_item label="Host" value={@form[:host].value} mono />
                  <.preview_item label="Branch" value={@form[:branch].value} mono />
                  <.preview_item
                    label="Server"
                    value={server_label(@servers, @form[:server_id].value)}
                  />
                  <.preview_item label="Systemd unit" value={@form[:systemd_unit].value} mono />
                  <.preview_item label="Release path" value={@form[:release_path].value} mono />
                </dl>
                <p class="mt-2 text-[11px] text-hd-muted">
                  Push webhook is provisioned on save. Runtime packages can come from
                  <span class="font-mono">.phoenix_paas/runtime-packages</span>
                  in the repo.
                </p>
              </div>

              <div
                :if={@github_repos != [] and not repo_selected?(@form)}
                class="text-xs text-hd-muted"
              >
                Repositories from your GitHub token. Select one to preview the deploy profile.
              </div>

              <.hidden_provision_fields
                :if={repo_selected?(@form) and not @show_advanced?}
                form={@form}
                include_server_id?={length(@servers) <= 1}
              />

              <div
                :if={@servers != [] and length(@servers) > 1 and repo_selected?(@form)}
                class="max-w-md"
              >
                <.input
                  field={@form[:server_id]}
                  type="select"
                  label="Target server"
                  options={server_options(@servers)}
                />
              </div>

              <div
                :if={@show_advanced?}
                id="app-advanced-fields"
                class="space-y-4 border-t border-hd-border pt-4"
              >
                <p class="font-mono text-[10px] font-semibold uppercase tracking-wider text-hd-muted">
                  Advanced overrides
                </p>
                <div class="grid gap-4 sm:grid-cols-2">
                  <.input field={@form[:name]} type="text" label="Name" required />
                  <.input field={@form[:slug]} type="text" label="Slug" required />
                  <.input field={@form[:host]} type="text" label="Host" required />
                  <.input field={@form[:branch]} type="text" label="Branch" />
                  <.input
                    :if={length(@servers) > 1}
                    field={@form[:server_id]}
                    type="select"
                    label="Server"
                    options={server_options(@servers)}
                  />
                  <.input
                    field={@form[:systemd_unit]}
                    type="text"
                    label="Systemd unit"
                    placeholder="phx-my-app"
                  />
                  <.input
                    field={@form[:release_path]}
                    type="text"
                    label="Release path"
                    placeholder="/opt/my_app"
                  />
                </div>
                <.input
                  field={@form[:runtime_packages_text]}
                  type="textarea"
                  label="Runtime packages (apt)"
                  placeholder="zip\nffmpeg\nimagemagick"
                  rows="4"
                />
              </div>

              <input
                :if={@show_advanced?}
                type="hidden"
                name="app[advanced]"
                value="true"
              />

              <div class="flex flex-wrap items-center gap-2">
                <button
                  :if={repo_selected?(@form)}
                  type="submit"
                  id="save-app-button"
                  class="paas-btn-primary"
                >
                  Register & connect webhook
                </button>
                <button
                  :if={repo_selected?(@form)}
                  type="button"
                  phx-click="toggle_advanced"
                  class="paas-btn-secondary"
                >
                  {if @show_advanced?, do: "Hide advanced", else: "Customize"}
                </button>
                <.link navigate={~p"/apps"} class="paas-btn-secondary">Cancel</.link>
              </div>
            </.form>
          </div>
        </div>

        <div id="apps-list" phx-update="stream" class="space-y-3">
          <div
            id="apps-empty"
            class="hidden only:block rounded-md border-2 border-dashed border-hd-border p-8 text-center text-hd-muted"
          >
            <p class="font-mono text-xs">
              › No applications configured. Please create an application profile above.
            </p>
            <.link
              :if={@servers != []}
              navigate={~p"/apps/new"}
              class="paas-btn-primary mt-4 inline-flex"
            >
              Register App
            </.link>
          </div>

          <div
            :for={{id, app} <- @streams.apps}
            id={id}
            class="paas-card p-4 transition-all hover:border-hd-orange/30"
          >
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <.link
                  navigate={~p"/apps/#{app.id}/deployments"}
                  class="font-semibold text-hd-orange hover:text-hd-orange-dark"
                >
                  {app.name}
                </.link>
                <.link
                  href={"https://#{app.host}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-mono text-sm text-hd-orange hover:text-hd-orange-dark hover:underline"
                >
                  {app.host}
                </.link>
              </div>
              <span class="rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[10px] text-hd-muted">
                {app.server.name}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :include_server_id?, :boolean, default: true

  defp hidden_provision_fields(assigns) do
    ~H"""
    <input type="hidden" name="app[name]" value={@form[:name].value} />
    <input type="hidden" name="app[slug]" value={@form[:slug].value} />
    <input type="hidden" name="app[host]" value={@form[:host].value} />
    <input type="hidden" name="app[branch]" value={@form[:branch].value} />
    <input
      :if={@include_server_id?}
      type="hidden"
      name="app[server_id]"
      value={@form[:server_id].value}
    />
    <input type="hidden" name="app[systemd_unit]" value={@form[:systemd_unit].value} />
    <input type="hidden" name="app[release_path]" value={@form[:release_path].value} />
    <input
      :if={@form[:runtime_packages_text].value}
      type="hidden"
      name="app[runtime_packages_text]"
      value={@form[:runtime_packages_text].value}
    />
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :mono, :boolean, default: false

  defp preview_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="font-mono text-[9px] uppercase tracking-wider text-hd-muted">{@label}</dt>
      <dd class={["truncate text-xs font-medium text-hd-text", @mono && "font-mono"]}>
        {@value || "—"}
      </dd>
    </div>
    """
  end

  defp repo_selected?(form) do
    case form[:github_repo].value do
      value when is_binary(value) -> String.trim(value) != ""
      _ -> false
    end
  end

  defp advanced_enabled?(params, current?) do
    param = Map.get(params, "advanced") || Map.get(params, :advanced)
    param in ["true", "on", true] || current?
  end

  defp maybe_put_advanced(params, true), do: Map.put(params, "advanced", "true")
  defp maybe_put_advanced(params, false), do: params

  defp server_options(servers) do
    Enum.map(servers, fn server -> {server.name, server.id} end)
  end

  defp server_label(servers, server_id) do
    servers
    |> Enum.find_value(fn server ->
      if to_string(server.id) == to_string(server_id), do: server.name
    end)
  end

  defp app_registered_message(:synced),
    do: "App registered — GitHub webhook connected for automatic deploys"

  defp app_registered_message(:no_token),
    do: "App registered — set GITHUB_TOKEN on the panel to auto-configure webhooks"

  defp app_registered_message({:error, message}),
    do: "App registered — webhook not configured (#{message})"
end
