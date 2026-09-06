defmodule PhoenixPaasWeb.ServerLive.Index do
  use PhoenixPaasWeb, :live_view

  alias PhoenixPaas.Servers
  alias PhoenixPaas.Servers.Server

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Servers")
     |> assign(:active_tab, :servers)
     |> stream(:servers, Servers.list_servers(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New server")
    |> assign(:server, %Server{})
    |> assign(:form, to_form(Servers.change_server(%Server{})))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Servers")
    |> assign(:server, nil)
    |> assign(:form, nil)
  end

  @impl true
  def handle_event("validate", %{"server" => server_params}, socket) do
    changeset =
      %Server{}
      |> Servers.change_server(apply_provider_defaults(server_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"server" => server_params}, socket) do
    server_params = apply_provider_defaults(server_params)

    case Servers.create_server(socket.assigns.current_scope, server_params) do
      {:ok, server} ->
        {:noreply,
         socket
         |> stream_insert(:servers, server)
         |> assign(:server_count, socket.assigns.server_count + 1)
         |> put_flash(:info, "Server created")
         |> push_navigate(to: ~p"/servers")}

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
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 class="font-display text-sm font-semibold text-hd-text">Deploy servers</h2>
            <p class="text-[11px] text-hd-muted">
              Hetzner Cloud and AWS Lightsail VMs hosting Phoenix and Go applications
            </p>
          </div>
          <.link :if={@live_action == :index} navigate={~p"/servers/new"} class="paas-btn-primary">
            <.icon name="hero-plus" class="size-3.5" /> New server
          </.link>
        </div>

        <div :if={@live_action == :new} class="paas-card">
          <div class="space-y-4 p-4">
            <h3 class="font-display text-sm font-semibold text-hd-text">Register server</h3>
            <.form
              for={@form}
              id="server-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-4"
            >
              <div class="grid gap-4 sm:grid-cols-2">
                <.input field={@form[:name]} type="text" label="Name" required />
                <.input field={@form[:host_ip]} type="text" label="Host IP" required />
                <.input
                  field={@form[:provider]}
                  type="select"
                  label="Provider"
                  options={[
                    {"Hetzner Cloud", "hetzner"},
                    {"AWS Lightsail", "lightsail"}
                  ]}
                />
                <.input field={@form[:ssh_user]} type="text" label="SSH user" />
                <.input field={@form[:region]} type="text" label="Region / location" />
                <.input
                  field={@form[:aws_instance_name]}
                  type="text"
                  label="Instance name"
                />
                <.input
                  field={@form[:deploy_mode]}
                  type="select"
                  label="Deploy mode"
                  options={[
                    {"Shared (multiple apps)", "shared"},
                    {"Dedicated (solo app)", "dedicated"}
                  ]}
                />
                <.input
                  field={@form[:ssh_private_key]}
                  type="textarea"
                  label="SSH private key (PEM)"
                  class="col-span-full font-mono text-xs"
                  placeholder="-----BEGIN OPENSSH PRIVATE KEY-----"
                />
              </div>
              <div class="flex gap-2">
                <button type="submit" class="paas-btn-primary">Save server</button>
                <.link navigate={~p"/servers"} class="paas-btn-secondary">Cancel</.link>
              </div>
            </.form>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <div id="servers-list" phx-update="stream" class="contents">
            <div
              id="servers-empty"
              class="hidden only:block rounded-md border-2 border-dashed border-hd-border p-8 text-center md:col-span-2 lg:col-span-3"
            >
              <div class="mx-auto mb-4 flex size-12 animate-pulse items-center justify-center rounded-md border border-hd-border bg-hd-aside text-hd-orange">
                <.icon name="hero-server-stack" class="size-6" />
              </div>
              <h3 class="font-display text-sm font-semibold text-hd-text">
                No registered VM instances
              </h3>
              <p class="mx-auto mt-1 max-w-md text-xs leading-relaxed text-hd-muted">
                Register a Hetzner Cloud or AWS Lightsail VM with its SSH key to start deploying.
              </p>
              <.link navigate={~p"/servers/new"} class="paas-btn-primary mt-4 inline-flex">
                Register New Server
              </.link>
            </div>

            <.link
              :for={{id, server} <- @streams.servers}
              id={id}
              navigate={~p"/servers/#{server.id}"}
              class="paas-card flex flex-col justify-between p-4 transition-all hover:border-hd-orange/30"
            >
              <div class="space-y-3">
                <div class="flex items-start justify-between">
                  <div class="space-y-0.5">
                    <h3 class="font-display text-xs font-semibold text-hd-text">{server.name}</h3>
                    <div class="flex flex-wrap gap-1">
                      <span class="inline-block rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[9px] font-medium text-hd-orange">
                        {server.provider || "lightsail"}
                      </span>
                      <span class="inline-block rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[9px] font-medium text-hd-muted">
                        {server.region}
                      </span>
                      <span class={[
                        "inline-block rounded border px-2 py-0.5 font-mono text-[9px] font-medium",
                        server.deploy_mode == "dedicated" &&
                          "border-hd-orange/40 bg-hd-orange/10 text-hd-orange",
                        server.deploy_mode != "dedicated" && "border-hd-border bg-hd-bg text-hd-muted"
                      ]}>
                        {if server.deploy_mode == "dedicated", do: "Dedicated", else: "Shared"}
                      </span>
                    </div>
                  </div>
                  <span class="flex items-center gap-1.5 rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[10px]">
                    <span class={[
                      "size-1.5 rounded-full",
                      server.instance_status == "running" && "animate-pulse bg-hd-green",
                      server.instance_status != "running" && "bg-hd-muted"
                    ]} />
                    <span class="font-semibold text-hd-muted">
                      {String.upcase(server.instance_status || "unknown")}
                    </span>
                  </span>
                </div>

                <div
                  :if={PhoenixPaas.Servers.Server.specs_configured?(server)}
                  class="grid grid-cols-3 gap-2 font-mono text-[10px]"
                >
                  <div class="rounded border border-hd-border bg-hd-bg px-2 py-1 text-center">
                    <p class="text-hd-muted">Plan</p>
                    <p class="font-semibold text-hd-text">{server.bundle_name}</p>
                  </div>
                  <div class="rounded border border-hd-border bg-hd-bg px-2 py-1 text-center">
                    <p class="text-hd-muted">RAM</p>
                    <p class="font-semibold text-hd-text">
                      {PhoenixPaas.Servers.Server.format_ram(server)}
                    </p>
                  </div>
                  <div class="rounded border border-hd-border bg-hd-bg px-2 py-1 text-center">
                    <p class="text-hd-muted">vCPU</p>
                    <p class="font-semibold text-hd-text">{server.cpu_count}</p>
                  </div>
                </div>

                <div
                  :if={not PhoenixPaas.Servers.Server.specs_configured?(server)}
                  class="rounded border border-dashed border-hd-border px-2.5 py-2 text-center text-[10px] text-hd-muted"
                >
                  Open to sync cloud specs
                </div>

                <div class="flex items-center justify-between rounded border border-hd-border bg-hd-bg px-2.5 py-1.5 font-mono text-[11px]">
                  <span class="text-hd-muted">Static IP:</span>
                  <span class="font-bold tracking-wider text-hd-text">{server.host_ip}</span>
                  <button
                    id={"copy-ip-#{server.id}"}
                    type="button"
                    phx-hook=".Copy"
                    data-clipboard={server.host_ip}
                    class="text-hd-muted transition-colors hover:text-hd-text"
                    aria-label="Copy IP"
                  >
                    <.icon name="hero-clipboard-document" class="size-3.5" />
                  </button>
                </div>
              </div>
            </.link>
          </div>

          <.link
            id="add-server-card"
            navigate={~p"/servers/new"}
            class="flex cursor-pointer flex-col items-center justify-center rounded-md border-2 border-dashed border-hd-border p-4 text-center transition-all hover:border-hd-muted hover:bg-hd-card/10"
          >
            <div class="flex size-8 items-center justify-center rounded-full border border-hd-border text-hd-muted">
              <.icon name="hero-plus" class="size-4" />
            </div>
            <p class="mt-1.5 text-[11px] font-semibold text-hd-text">Add server</p>
            <p class="text-[10px] text-hd-muted">Hetzner or Lightsail</p>
          </.link>
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
          export default {
            mounted() {
              this.el.addEventListener("click", (event) => {
                event.preventDefault();
                event.stopPropagation();
                navigator.clipboard.writeText(this.el.dataset.clipboard || "");
              });
            }
          }
        </script>
      </div>
    </Layouts.app>
    """
  end

  defp apply_provider_defaults(%{"provider" => "hetzner"} = params) do
    params
    |> put_if_blank_or("region", "fsn1", ["", "us-east-1"])
    |> put_if_blank_or("ssh_user", "ubuntu", ["", nil])
  end

  defp apply_provider_defaults(params), do: params

  defp put_if_blank_or(params, key, value, replace) do
    current = Map.get(params, key)

    if current in replace do
      Map.put(params, key, value)
    else
      params
    end
  end
end
