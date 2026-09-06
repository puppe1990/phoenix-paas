defmodule PhoenixPaasWeb.PaasShell do
  @moduledoc false
  use Phoenix.Component

  import PhoenixPaasWeb.CoreComponents, only: [icon: 1]
  use PhoenixPaasWeb, :verified_routes

  attr :flash, :map, required: true
  attr :active_tab, :atom, required: true
  attr :server_count, :integer, default: 0
  attr :app_count, :integer, default: 0
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-hd-bg text-hd-text antialiased">
      <header class="sticky top-0 z-40 flex flex-wrap items-center justify-between gap-3 border-b border-hd-border bg-hd-aside px-4 py-3">
        <.link
          href={~p"/"}
          class="group flex items-center gap-2.5 rounded-lg transition-opacity hover:opacity-90"
          aria-label="Back to dashboard"
        >
          <div class="flex size-9 items-center justify-center rounded-lg border border-hd-border bg-hd-card transition-colors group-hover:border-hd-orange/40">
            <.icon name="hero-fire" class="size-5 text-hd-orange" />
          </div>
          <div>
            <div class="flex items-center gap-1.5">
              <h1 class="font-display text-lg font-semibold tracking-tight">Phoenix PaaS</h1>
              <span class="rounded-full border border-hd-border bg-hd-card px-2 py-0.5 font-mono text-[10px] uppercase tracking-widest text-hd-muted">
                MVP
              </span>
            </div>
            <p class="text-xs text-hd-muted">
              Hetzner Cloud & GitHub webhooks for Phoenix and Go apps
            </p>
          </div>
        </.link>

        <nav class="flex flex-wrap items-center gap-2 text-xs font-medium">
          <%= if @current_scope do %>
            <span class="hidden rounded-md border border-hd-border bg-hd-card px-2.5 py-1.5 text-hd-muted sm:inline">
              {@current_scope.user.email}
            </span>
            <.link href={~p"/users/settings"} class="paas-btn-secondary px-3 py-1.5">
              Settings
            </.link>
            <.link href={~p"/users/log-out"} method="delete" class="paas-btn-secondary px-3 py-1.5">
              Log out
            </.link>
          <% else %>
            <.link href={~p"/users/log-in"} class="paas-btn-secondary px-3 py-1.5">
              Log in
            </.link>
            <.link href={~p"/users/register"} class="paas-btn-primary px-3 py-1.5">
              Register
            </.link>
          <% end %>
        </nav>
      </header>

      <main class="mx-auto w-full max-w-7xl flex-1 space-y-4 p-3 md:p-4">
        <div class="mx-auto w-full max-w-[1440px] rounded-lg border border-hd-border bg-hd-bg shadow-[0_0_0_1px_rgba(48,54,61,0.5)] transition-all duration-300">
          <div class="relative min-h-[700px] overflow-hidden rounded-lg p-4 lg:p-6">
            <div class="paas-grid-bg pointer-events-none absolute inset-0 opacity-[0.03]" />

            <div class="relative z-10 mb-4 flex flex-wrap items-center justify-between gap-3 border-b border-hd-border pb-4">
              <div class="flex items-center gap-1 rounded-lg border border-hd-border bg-hd-aside p-1">
                <.tab_link
                  navigate={~p"/"}
                  active?={@active_tab == :dashboard}
                  icon="hero-squares-2x2"
                  label="Dashboard"
                />
                <.tab_link
                  navigate={~p"/servers"}
                  active?={@active_tab == :servers}
                  icon="hero-server-stack"
                  label="Servers"
                  count={@server_count}
                />
                <.tab_link
                  navigate={~p"/apps"}
                  active?={@active_tab == :apps}
                  icon="hero-globe-alt"
                  label="App Details"
                  count={@app_count}
                />
              </div>

              <div class="flex items-center gap-2">
                <.link navigate={~p"/servers/new"} class="paas-btn-secondary">
                  <.icon name="hero-plus" class="size-3.5 text-hd-orange" /> New VM Server
                </.link>
                <.link navigate={~p"/apps/new"} class="paas-btn-primary">
                  <.icon name="hero-plus" class="size-3.5" /> Register App
                </.link>
              </div>
            </div>

            <div class="relative z-10">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </main>

      <footer class="mt-auto border-t border-hd-border bg-hd-aside px-4 py-3.5 text-xs text-hd-muted select-none">
        <div class="mx-auto flex max-w-7xl flex-col items-center justify-between gap-3 md:flex-row">
          <div class="flex items-center gap-1.5">
            <.icon name="hero-fire" class="size-3.5 text-hd-orange" />
            <span class="font-mono text-[10px] font-semibold tracking-wider text-hd-text">
              PHOENIX PAAS CLUSTER MGMT
            </span>
            <span class="rounded-full border border-hd-border bg-hd-card px-2 py-0.5 text-[10px]">
              v0.1.0-alpha
            </span>
          </div>
          <div class="flex items-center gap-3 font-mono text-[10px]">
            <span>Client Region: US-EAST</span>
            <span class="text-hd-green">Node Sync: ONLINE</span>
          </div>
        </div>
      </footer>

      <.flash_toast flash={@flash} />
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :active?, :boolean, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, default: nil

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-semibold tracking-wide transition-all",
        @active? && "border border-hd-border bg-hd-card text-hd-orange",
        !@active? && "text-hd-muted hover:text-hd-text"
      ]}
    >
      <.icon name={@icon} class="size-3.5" />
      <span>{@label}</span>
      <span
        :if={@count != nil}
        class="rounded-md border border-hd-border bg-hd-card px-1.5 py-0.5 font-mono text-[10px] text-hd-orange"
      >
        {@count}
      </span>
    </.link>
    """
  end

  attr :flash, :map, required: true

  defp flash_toast(assigns) do
    ~H"""
    <div
      id="flash-toast"
      aria-live="polite"
      class="pointer-events-none fixed top-20 left-1/2 z-50 -translate-x-1/2"
    >
      <div
        :if={msg = Phoenix.Flash.get(@flash, :info)}
        class="flex items-center gap-2 rounded-md border border-hd-green bg-hd-card px-3 py-2 font-mono text-[11px] font-medium text-hd-green shadow-xl"
      >
        <span class="size-1.5 rounded-full bg-hd-green" />
        {msg}
      </div>
      <div
        :if={msg = Phoenix.Flash.get(@flash, :error)}
        class="flex items-center gap-2 rounded-md border border-hd-orange bg-hd-card px-3 py-2 font-mono text-[11px] font-medium text-hd-orange shadow-xl"
      >
        <span class="size-1.5 rounded-full bg-hd-orange" />
        {msg}
      </div>
    </div>
    """
  end
end
