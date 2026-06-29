defmodule PhoenixPaasWeb.PaasComponents do
  @moduledoc false
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import PhoenixPaasWeb.CoreComponents, only: [icon: 1]

  @repo_picker_limit 50

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

  attr :id, :string, default: "deploy-terminal"
  attr :deployment, :map, required: true
  attr :active?, :boolean, default: false
  attr :duration, :string, default: nil

  def deploy_terminal(assigns) do
    lines =
      assigns.deployment.log
      |> to_string()
      |> String.split("\n", trim: true)

    assigns = assign(assigns, :lines, lines)

    ~H"""
    <div
      id={@id}
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
        <div class="flex items-center gap-3">
          <span :if={@duration && @duration != "—"} class="tabular-nums text-hd-text">
            {@duration}
          </span>
          <span>Target VM: us-east-1</span>
        </div>
      </div>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :repos, :list, required: true
  attr :repo_search, :string, default: ""
  attr :open?, :boolean, default: false

  def github_repo_picker(assigns) do
    selected = to_string(assigns.field.value || "")
    filtered = filter_repo_options(assigns.repos, assigns.repo_search, @repo_picker_limit)
    total_matches = count_repo_matches(assigns.repos, assigns.repo_search)

    assigns =
      assigns
      |> assign(:selected, selected)
      |> assign(:filtered, filtered)
      |> assign(:total_matches, total_matches)
      |> assign(
        :search_display,
        repo_search_display(assigns.open?, assigns.repo_search, selected)
      )
      |> assign(:errors, assigns.field.errors)

    ~H"""
    <div
      id="github-repo-picker"
      class="fieldset relative mb-2"
      phx-click-away={JS.push("close_repo_picker")}
    >
      <label for="github-repo-search">
        <span class="label mb-1">GitHub repository</span>
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-hd-muted"
          />
          <input
            type="text"
            id="github-repo-search"
            name="repo_search"
            value={@search_display}
            phx-focus="open_repo_picker"
            phx-keyup="search_repos"
            phx-debounce="150"
            placeholder="Search repositories…"
            autocomplete="off"
            class={[
              "paas-input w-full pl-9",
              @errors != [] && "border-rose-500"
            ]}
          />
          <input type="hidden" name={@field.name} id={@field.id} value={@selected} />
        </div>
      </label>

      <ul
        :if={@open?}
        id="github-repo-options"
        class="absolute z-20 mt-1 max-h-56 w-full overflow-y-auto rounded-md border border-hd-border bg-hd-card shadow-xl"
      >
        <li :if={@filtered == []} class="px-3 py-2 text-xs text-hd-muted">
          No repositories match your search.
        </li>
        <li :for={{label, value} <- @filtered} id={"github-repo-option-#{slugify_option_id(value)}"}>
          <button
            type="button"
            phx-click="pick_repo"
            phx-value-repo={value}
            class={[
              "flex w-full items-center px-3 py-2 text-left font-mono text-xs transition-colors hover:bg-hd-aside",
              @selected == value && "bg-hd-aside/80 text-hd-orange"
            ]}
          >
            {label}
          </button>
        </li>
        <li
          :if={@total_matches > @repo_picker_limit}
          class="border-t border-hd-border px-3 py-2 text-[10px] text-hd-muted"
        >
          Showing first 50 of {@total_matches} matches. Refine your search.
        </li>
      </ul>

      <p :for={msg <- @errors} class="mt-1 text-xs text-rose-400">
        {translate_form_error(msg)}
      </p>
    </div>
    """
  end

  @doc false
  def filter_repo_options(repos, query, limit \\ @repo_picker_limit) do
    repos
    |> matching_repo_options(query)
    |> Enum.take(limit)
  end

  @doc false
  def count_repo_matches(repos, query) do
    repos |> matching_repo_options(query) |> length()
  end

  defp matching_repo_options(repos, query) do
    query = String.downcase(String.trim(to_string(query || "")))

    Enum.filter(repos, fn {label, _value} ->
      query == "" or String.contains?(String.downcase(label), query)
    end)
  end

  defp repo_search_display(true, repo_search, _selected), do: repo_search

  defp repo_search_display(false, _repo_search, selected) when selected != "",
    do: selected

  defp repo_search_display(false, repo_search, _selected), do: repo_search

  defp translate_form_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp translate_form_error(msg) when is_binary(msg), do: msg

  defp slugify_option_id(value) do
    value
    |> String.replace("/", "-")
    |> String.replace(~r/[^a-zA-Z0-9-]+/u, "-")
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
