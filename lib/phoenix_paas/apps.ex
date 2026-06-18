defmodule PhoenixPaas.Apps do
  @moduledoc """
  Manages Phoenix apps registered for deployment.
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Apps.{App, AppEnvVar}

  def list_apps do
    Repo.all(from a in App, order_by: [asc: a.name], preload: [:server])
  end

  def get_app!(id), do: Repo.get!(App, id) |> Repo.preload([:server, :env_vars])

  def get_app_by_repo(github_repo) when is_binary(github_repo) do
    Repo.get_by(App, github_repo: github_repo)
  end

  def create_app(attrs) do
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
end
