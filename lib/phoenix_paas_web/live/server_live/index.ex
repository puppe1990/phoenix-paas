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
     |> assign(:browser_path, "servers")
     |> stream(:servers, Servers.list_servers())}
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
      |> Servers.change_server(server_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"server" => server_params}, socket) do
    case Servers.create_server(server_params) do
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
      active_tab={@active_tab}
      browser_path={@browser_path}
      server_count={@server_count}
      app_count={@app_count}
    >
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 class="font-display text-sm font-semibold text-hd-text">AWS Lightsail VM Units</h2>
            <p class="text-[11px] text-hd-muted">
              Virtual Private Server cluster systems hosting Phoenix release application units
            </p>
          </div>
          <.link :if={@live_action == :index} navigate={~p"/servers/new"} class="paas-btn-primary">
            <.icon name="hero-plus" class="size-3.5" /> New server
          </.link>
        </div>

        <div :if={@live_action == :new} class="paas-card">
          <div class="space-y-4 p-4">
            <h3 class="font-display text-sm font-semibold text-hd-text">Register Lightsail VM</h3>
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
                <.input field={@form[:ssh_user]} type="text" label="SSH user" />
                <.input field={@form[:region]} type="text" label="Region" />
                <.input field={@form[:aws_instance_name]} type="text" label="AWS instance name" />
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
                To begin deploying, please link your first Amazon Lightsail virtual private server instance.
                Map static IP boundaries to enable automatic SSH and webhook dispatch features.
              </p>
              <.link navigate={~p"/servers/new"} class="paas-btn-primary mt-4 inline-flex">
                Register New Server
              </.link>
            </div>

            <div
              :for={{id, server} <- @streams.servers}
              id={id}
              class="paas-card flex flex-col justify-between p-4 transition-all hover:border-hd-orange/30"
            >
              <div class="space-y-3">
                <div class="flex items-start justify-between">
                  <div class="space-y-0.5">
                    <h3 class="font-display text-xs font-semibold text-hd-text">{server.name}</h3>
                    <span class="inline-block rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[9px] font-medium text-hd-orange">
                      {server.region}
                    </span>
                  </div>
                  <span class="flex items-center gap-1.5 rounded border border-hd-border bg-hd-bg px-2 py-0.5 font-mono text-[10px]">
                    <span class="size-1.5 animate-pulse rounded-full bg-hd-green" />
                    <span class="font-semibold text-hd-muted">ONLINE</span>
                  </span>
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
            </div>
          </div>

          <.link
            id="add-server-card"
            navigate={~p"/servers/new"}
            class="flex cursor-pointer flex-col items-center justify-center rounded-md border-2 border-dashed border-hd-border p-4 text-center transition-all hover:border-hd-muted hover:bg-hd-card/10"
          >
            <div class="flex size-8 items-center justify-center rounded-full border border-hd-border text-hd-muted">
              <.icon name="hero-plus" class="size-4" />
            </div>
            <p class="mt-1.5 text-[11px] font-semibold text-hd-text">Add AWS Lightsail VM</p>
            <p class="text-[10px] text-hd-muted">Link next VPS node</p>
          </.link>
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
          export default {
            mounted() {
              this.el.addEventListener("click", () => {
                navigator.clipboard.writeText(this.el.dataset.clipboard || "");
              });
            }
          }
        </script>
      </div>
    </Layouts.app>
    """
  end
end
