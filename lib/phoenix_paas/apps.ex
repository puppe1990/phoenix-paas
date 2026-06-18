defmodule PhoenixPaas.Apps do
  @moduledoc """
  Manages Phoenix apps registered for deployment.
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Accounts.Scope
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Apps.{App, AppEnvVar}

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

    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
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

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
