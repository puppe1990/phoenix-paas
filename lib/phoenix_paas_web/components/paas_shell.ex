defmodule PhoenixPaasWeb.PaasShell do
  @moduledoc false
  use Phoenix.Component

  import PhoenixPaasWeb.CoreComponents, only: [icon: 1]
  use PhoenixPaasWeb, :verified_routes

  attr :flash, :map, required: true
  attr :active_tab, :atom, required: true
  attr :server_count, :integer, default: 0
  attr :app_count, :integer, default: 0
  attr :browser_path, :string, default: "dashboard"
  slot :inner_block, required: true

  def shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-hd-bg text-hd-text antialiased">
      <header class="sticky top-0 z-40 flex flex-wrap items-center justify-between border-b border-hd-border bg-hd-aside px-4 py-3">
        <div class="flex items-center gap-2.5">
          <div class="flex size-9 items-center justify-center rounded-lg border border-hd-border bg-hd-card">
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
              AWS Lightsail & GitHub Webhooks deploy pipeline for Elixir OTP nodes
            </p>
          </div>
        </div>
      </header>

      <main class="mx-auto w-full max-w-7xl flex-1 space-y-4 p-3 md:p-4">
        <div class="flex gap-2.5 rounded-md border border-hd-border bg-hd-card p-3 shadow-sm">
          <.icon name="hero-sparkles" class="mt-0.5 size-4 shrink-0 text-hd-orange" />
          <div class="space-y-0.5 text-xs">
            <p class="font-display font-semibold text-hd-orange">Interactive Control Panel</p>
            <p class="leading-relaxed text-hd-muted">
              Manage Lightsail VMs, register Phoenix apps, and deploy OTP releases via manual trigger or GitHub webhooks.
            </p>
          </div>
        </div>

        <div class="mx-auto w-full max-w-[1440px] rounded-lg border border-hd-border bg-hd-bg shadow-xl transition-all duration-300">
          <.browser_chrome path={@browser_path} />

          <div class="relative min-h-[700px] overflow-hidden rounded-b-lg p-4 lg:p-6">
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

  attr :path, :string, required: true

  defp browser_chrome(assigns) do
    ~H"""
    <div class="flex select-none items-center justify-between rounded-t-lg border-b border-hd-border bg-hd-aside px-3 py-2">
      <div class="flex w-1/4 items-center gap-1.5">
        <span class="size-2.5 rounded-full bg-[#FF5F56]" />
        <span class="size-2.5 rounded-full bg-[#FFBD2E]" />
        <span class="size-2.5 rounded-full bg-[#27C93F]" />
        <span class="ml-2 hidden font-mono text-[9px] font-medium uppercase tracking-wider text-hd-muted sm:inline">
          AWS Lightsail: SECURE
        </span>
      </div>

      <div class="max-w-lg flex-1">
        <div class="flex items-center justify-between rounded border border-hd-border bg-hd-bg px-2.5 py-0.5 font-mono text-xs text-hd-muted transition-all focus-within:border-hd-orange">
          <div class="flex min-w-0 items-center gap-1 truncate">
            <.icon name="hero-shield-check" class="size-3 shrink-0 text-hd-green" />
            <span>https://</span>
            <span class="truncate text-hd-text">panel.phoenixpaas.io</span>
            <span>/</span>
            <span class="truncate capitalize text-hd-orange">{@path}</span>
          </div>
        </div>
      </div>

      <div class="flex w-1/4 items-center justify-end gap-2">
        <div class="hidden items-center gap-1 font-mono text-[10px] text-hd-muted md:flex">
          <span class="size-1 rounded-full bg-hd-green" />
          <span>prod-cluster</span>
        </div>
      </div>
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
        @active? && "border border-hd-border bg-hd-card text-hd-orange shadow-sm",
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
