defmodule PhoenixPaasWeb.PaasComponents do
  @moduledoc false
  use Phoenix.Component

  import PhoenixPaasWeb.CoreComponents, only: [icon: 1]

  attr :status, :atom, required: true

  def deploy_status_badge(assigns) do
    {class, pulse?, label} =
      case assigns.status do
        :queued -> {"text-hd-orange", true, "queued"}
        :running -> {"text-sky-400", true, "running"}
        :success -> {"text-hd-green", false, "success"}
        :failed -> {"text-rose-500", false, "failed"}
      end

    assigns = assign(assigns, class: class, pulse?: pulse?, label: label)

    ~H"""
    <span class={["inline-flex items-center gap-1.5 font-mono text-xs capitalize", @class]}>
      <span
        :if={@pulse?}
        class={[
          "size-1.5 rounded-full bg-current",
          @status == :queued && "animate-ping",
          @status == :running && "animate-pulse"
        ]}
      />
      <span :if={not @pulse?} class="size-1.5 rounded-full bg-current" />
      {@label}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false
  attr :hidden?, :boolean, default: false

  def copy_field(assigns) do
    ~H"""
    <div class="space-y-1">
      <span
        :if={@label != ""}
        class="font-mono text-[9px] font-semibold uppercase tracking-wider text-hd-muted"
      >
        {@label}
      </span>
      <div class="flex items-center justify-between gap-2 rounded border border-hd-border bg-hd-aside px-2.5 py-1.5 text-xs">
        <span class={["min-w-0 flex-1 truncate font-medium text-hd-text", @mono && "font-mono"]}>
          {if @hidden?, do: String.duplicate("•", 32), else: @value}
        </span>
        <button
          :if={not @hidden?}
          id={"copy-#{@id}"}
          type="button"
          phx-hook=".Copy"
          data-clipboard={@value}
          class="shrink-0 text-hd-muted transition-colors hover:text-hd-orange"
          aria-label={"Copy #{@label}"}
        >
          <.icon name="hero-clipboard-document" class="size-3.5" />
        </button>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
          export default {
            mounted() {
              this.el.addEventListener("click", () => {
                const text = this.el.dataset.clipboard || "";
                navigator.clipboard.writeText(text).then(() => {
                  this.el.classList.add("text-hd-green");
                  setTimeout(() => this.el.classList.remove("text-hd-green"), 1200);
                });
              });
            }
          }
        </script>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :hint, :string, default: nil
  attr :icon, :string, default: "hero-server-stack"

  def metric_card(assigns) do
    ~H"""
    <div class="paas-card group flex cursor-pointer items-center justify-between p-4 transition-all hover:border-hd-orange/40">
      <div class="space-y-0.5">
        <p class="block font-mono text-[10px] font-semibold uppercase tracking-wider text-hd-muted">
          {@title}
        </p>
        <div class="flex items-baseline gap-1.5">
          <p class="font-mono text-2xl font-bold tabular-nums text-hd-text">{@value}</p>
          <p :if={@hint} class="font-sans text-[11px] text-hd-muted">{@hint}</p>
        </div>
      </div>
      <div class="flex size-9 items-center justify-center rounded border border-hd-border bg-hd-aside transition-colors">
        <.icon
          name={@icon}
          class="size-5 text-hd-orange transition-transform group-hover:scale-110"
        />
      </div>
    </div>
    """
  end

  attr :deployment, :map, required: true
  attr :active?, :boolean, default: false

  def deploy_terminal(assigns) do
    lines =
      assigns.deployment.log
      |> to_string()
      |> String.split("\n", trim: true)

    assigns = assign(assigns, :lines, lines)

    ~H"""
    <div
      id="deploy-terminal"
      class="overflow-hidden rounded-md border border-hd-border bg-hd-bg font-mono text-[11px] text-hd-text"
    >
      <div class="flex items-center justify-between border-b border-hd-border bg-hd-aside px-3 py-1.5">
        <div class="flex items-center gap-1.5">
          <.icon name="hero-command-line" class="size-3.5 text-hd-orange" />
          <span class="text-[10px] font-semibold tracking-wider text-hd-muted">
            BUILD CONTAINER SHELL
          </span>
          <span class="rounded border border-hd-border bg-hd-card px-1 py-0.5 font-mono text-[9px] text-hd-muted">
            SHA: {@deployment.git_sha}
          </span>
        </div>
        <.deploy_status_badge status={@deployment.status} />
      </div>

      <div
        id="deploy-terminal-body"
        phx-hook=".TerminalScroll"
        class="h-56 space-y-0.5 overflow-y-auto p-3 leading-normal"
      >
        <div :if={@lines == []} class="text-hd-muted">Waiting for build output…</div>
        <div :for={{line, index} <- Enum.with_index(@lines)} class="flex">
          <span class="mr-2.5 w-5 shrink-0 select-none text-right text-hd-muted/40">
            {String.pad_leading(Integer.to_string(index + 1), 2, "0")}
          </span>
          <span class={terminal_line_class(line)}>{line}</span>
        </div>
        <span :if={@active?} class="ml-8 inline-block h-3 w-1 animate-pulse bg-hd-orange" />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".TerminalScroll">
          export default {
            mounted() { this.scroll(); },
            updated() { this.scroll(); },
            scroll() {
              this.el.scrollTop = this.el.scrollHeight;
            }
          }
        </script>
      </div>

      <div class="flex items-center justify-between border-t border-hd-border bg-hd-aside px-3 py-1 text-[10px] text-hd-muted">
        <div class="flex items-center gap-2">
          <span>Elixir 1.16.2</span>
          <span>OTP 26.2.1</span>
          <span>Phoenix 1.7.12</span>
        </div>
        <span>Target VM: us-east-1</span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false
  attr :sub, :string, default: nil

  def info_tile(assigns) do
    ~H"""
    <div class="paas-card flex flex-col justify-between space-y-1 p-3">
      <span class="font-mono text-[9px] font-bold uppercase tracking-widest text-hd-muted">
        {@label}
      </span>
      <p class={["truncate text-xs font-semibold text-hd-text", @mono && "font-mono"]}>{@value}</p>
      <p :if={@sub} class="block font-mono text-[10px] text-hd-muted">{@sub}</p>
    </div>
    """
  end

  defp terminal_line_class(line) do
    cond do
      String.starts_with?(line, "==>") ->
        "font-semibold text-hd-orange"

      String.starts_with?(line, "$") ->
        "text-hd-muted"

      String.contains?(line, "SUCCESS") or String.contains?(line, "successful") ->
        "text-hd-green"

      String.contains?(line, "FAIL") or String.contains?(line, "Error") ->
        "font-medium text-rose-500"

      true ->
        "text-hd-text"
    end
  end
end
