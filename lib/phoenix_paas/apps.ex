defmodule PhoenixPaas.Apps do
  @moduledoc """
  Manages Phoenix apps registered for deployment.
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Accounts.Scope
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Apps.{App, AppEnvVar}
  alias PhoenixPaas.Github

  require Logger

  def list_apps(%Scope{tenant: tenant}) do
    Repo.all(
      from a in App,
        where: a.tenant_id == ^tenant.id,
        order_by: [asc: a.name],
        preload: [:server]
    )
  end

  def get_app!(id) when is_integer(id) do
    Repo.get!(App, id) |> Repo.preload([:server, :env_vars])
  end

  def get_app!(%Scope{tenant: tenant}, id) do
    Repo.one!(
      from a in App,
        where: a.tenant_id == ^tenant.id and a.id == ^id,
        preload: [:server, :env_vars]
    )
  end

  def get_app_by_repo(github_repo) when is_binary(github_repo) do
    Repo.get_by(App, github_repo: github_repo)
  end

  def list_apps_by_repo(github_repo) when is_binary(github_repo) do
    Repo.all(from a in App, where: a.github_repo == ^github_repo)
  end

  def create_app(%Scope{tenant: tenant}, attrs) do
    attrs = Map.put(stringify_keys(attrs), "tenant_id", tenant.id)

    with {:ok, app} <-
           %App{}
           |> App.changeset(attrs)
           |> Repo.insert() do
      {status, app} = sync_github_webhook(app)
      {:ok, app, status}
    end
  end

  @doc """
  Provisions (or updates) the GitHub push webhook for an app.

  Returns `{status, app}` where status is `:synced`, `:no_token`, or `{:error, message}`.
  """
  def sync_github_webhook(%App{} = app) do
    case Github.ensure_webhook(app) do
      :ok ->
        {:synced, app}

      {:error, :missing_token} ->
        Logger.warning("GitHub webhook not synced for #{app.slug}: GITHUB_TOKEN is not set")
        {:no_token, app}

      {:error, reason} ->
        message = if is_binary(reason), do: reason, else: inspect(reason)
        Logger.warning("GitHub webhook not synced for #{app.slug}: #{message}")
        {{:error, message}, app}
    end
  end

  @doc """
  Provisions GitHub push webhooks for every registered app.

  Returns a list of `{slug, status}` tuples where status is `:synced`, `:no_token`,
  or `{:error, message}`.
  """
  def sync_all_github_webhooks do
    Repo.all(App)
    |> Enum.map(fn app ->
      {status, _app} = sync_github_webhook(app)
      {app.slug, status}
    end)
  end

  def change_app(app, attrs \\ %{}) do
    App.changeset(app, attrs)
  end

  def put_env_var(%App{} = app, key, value) when is_binary(key) and is_binary(value) do
    %AppEnvVar{}
    |> AppEnvVar.changeset(%{key: key, value: value, app_id: app.id})
    |> Repo.insert(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:app_id, :key]
    )
  end

  def env_map(%App{} = app) do
    vars =
      app
      |> Repo.preload(:env_vars)
      |> Map.fetch!(:env_vars)
      |> Map.new(fn %{key: key, value: value} -> {key, value} end)

    Map.put(vars, "PHX_HOST", app.host)
  end

  @sensitive_markers ~w(SECRET TOKEN PASSWORD _KEY)

  def sensitive_env_key?(key) when is_binary(key) do
    upper = String.upcase(key)

    Enum.any?(@sensitive_markers, fn marker ->
      String.contains?(upper, marker)
    end)
  end

  def display_env_value(key, value, reveal?) when is_binary(key) and is_binary(value) do
    if reveal? or not sensitive_env_key?(key) do
      value
    else
      mask_env_value(value)
    end
  end

  def list_env_vars_for_display(%App{} = app) do
    app = Repo.preload(app, :env_vars)

    app.env_vars
    |> Enum.map(fn %{key: key, value: value} ->
      %{key: key, value: value, sensitive?: sensitive_env_key?(key)}
    end)
    |> Enum.sort_by(& &1.key)
  end

  defp mask_env_value(value) do
    len = String.length(value)

    cond do
      len <= 4 ->
        String.duplicate("•", len)

      len <= 8 ->
        String.duplicate("•", 8)

      true ->
        String.slice(value, 0, 2) <>
          String.duplicate("•", min(16, len - 4)) <> String.slice(value, -2, 2)
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
