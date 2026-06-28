defmodule PhoenixPaasWeb.AppLive.Index do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.{Apps, Github, Servers}
  alias PhoenixPaas.Apps.App

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Apps")
     |> assign(:active_tab, :apps)
     |> assign(:browser_path, "apps")
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
    |> assign(:form, to_form(Apps.change_app(%App{})))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Apps")
    |> assign(:app, nil)
    |> assign(:form, nil)
    |> assign(:github_repos, [])
  end

  @impl true
  def handle_event("validate", %{"app" => app_params}, socket) do
    changeset =
      %App{}
      |> Apps.change_app(app_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"app" => app_params}, socket) do
    case Apps.create_app(socket.assigns.current_scope, app_params) do
      {:ok, app, webhook_status} ->
        app = Apps.get_app!(socket.assigns.current_scope, app.id)

        {:noreply,
         socket
         |> stream_insert(:apps, app)
         |> assign(:app_count, socket.assigns.app_count + 1)
         |> put_flash(:info, app_registered_message(webhook_status))
         |> push_navigate(to: ~p"/apps/#{app.id}")}

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
      browser_path={@browser_path}
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
            <h3 class="font-display text-sm font-semibold text-hd-text">
              Register Phoenix Application
            </h3>
            <.form for={@form} id="app-form" phx-change="validate" phx-submit="save" class="space-y-4">
              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@form[:name]} type="text" label="Name" required />
                <.input field={@form[:slug]} type="text" label="Slug" required />
                <.input
                  :if={@github_repos == []}
                  field={@form[:github_repo]}
                  type="text"
                  label="GitHub repo (owner/name)"
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
                <p :if={@github_repos != []} class="sm:col-span-2 text-xs text-hd-muted">
                  Repositories from your GitHub token. Saving an app automatically configures the push webhook (Heroku-style).
                </p>
                <.input field={@form[:host]} type="text" label="Host" required />
                <.input field={@form[:branch]} type="text" label="Branch" />
                <.input
                  field={@form[:server_id]}
                  type="select"
                  label="Server"
                  options={server_options(@servers)}
                />
                <.input
                  field={@form[:systemd_unit]}
                  type="text"
                  label="Systemd unit"
                  placeholder="trip_planner_ia"
                />
                <.input
                  field={@form[:release_path]}
                  type="text"
                  label="Release path"
                  placeholder="/opt/trip_planner_ia"
                />
              </div>
              <.input
                field={@form[:runtime_packages_text]}
                type="textarea"
                label="Runtime packages (apt)"
                placeholder="zip\nffmpeg\nimagemagick"
                rows="4"
              />
              <p class="text-xs text-hd-muted">
                Installed automatically on every deploy. You can also add
                <span class="font-mono">.phoenix_paas/runtime-packages</span>
                to the app repo (one package per line).
              </p>
              <div class="flex gap-2">
                <button type="submit" class="paas-btn-primary">Save app</button>
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
                  navigate={~p"/apps/#{app.id}"}
                  class="font-semibold text-hd-orange hover:text-hd-orange-dark"
                >
                  {app.name}
                </.link>
                <p class="font-mono text-sm text-hd-muted">{app.host}</p>
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

  defp server_options(servers) do
    Enum.map(servers, fn server -> {server.name, server.id} end)
  end

  defp app_registered_message(:synced),
    do: "App registered — GitHub webhook connected for automatic deploys"

  defp app_registered_message(:no_token),
    do: "App registered — set GITHUB_TOKEN on the panel to auto-configure webhooks"

  defp app_registered_message({:error, message}),
    do: "App registered — webhook not configured (#{message})"
end
