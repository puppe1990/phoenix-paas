defmodule PhoenixPaas.Apps.App do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixPaas.Accounts.Tenant
  alias PhoenixPaas.Apps.AppEnvVar
  alias PhoenixPaas.Servers.Server

  schema "apps" do
    field :name, :string
    field :slug, :string
    field :github_repo, :string
    field :branch, :string, default: "main"
    field :host, :string
    field :port, :integer, default: 4000
    field :systemd_unit, :string
    field :release_path, :string
    field :webhook_secret, :string
    field :auto_deploy, :boolean, default: true
    field :runtime_apt_packages, {:array, :string}, default: []
    field :runtime_packages_text, :string, virtual: true

    belongs_to :tenant, Tenant
    belongs_to :server, Server
    has_many :env_vars, AppEnvVar

    timestamps(type: :utc_datetime)
  end

  def changeset(app, attrs) do
    app
    |> cast(attrs, [
      :name,
      :slug,
      :github_repo,
      :branch,
      :host,
      :port,
      :systemd_unit,
      :release_path,
      :webhook_secret,
      :auto_deploy,
      :runtime_apt_packages,
      :runtime_packages_text,
      :server_id,
      :tenant_id
    ])
    |> validate_required([:name, :slug, :github_repo, :host, :server_id, :tenant_id])
    |> cast_runtime_packages()
    |> put_runtime_packages_text()
    |> validate_format(:github_repo, ~r/^[^\/]+\/[^\/]+$/, message: "must be owner/repo")
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:slug, name: :apps_tenant_id_slug_index)
    |> unique_constraint(:github_repo, name: :apps_tenant_id_github_repo_index)
    |> foreign_key_constraint(:server_id)
    |> put_default_webhook_secret()
    |> put_deploy_defaults()
  end

  def release_name("trip-planner"), do: "trip_planner_ia"
  def release_name("catalogo"), do: "catalog_platform"
  def release_name(slug) when is_binary(slug), do: String.replace(slug, "-", "_")

  def default_systemd_unit("trip-planner"), do: "trip_planner_ia"
  def default_systemd_unit(slug) when is_binary(slug), do: "phx-#{slug}"

  def default_release_path("trip-planner"), do: "/opt/trip_planner_ia"
  def default_release_path(slug) when is_binary(slug), do: "/opt/#{release_name(slug)}"

  def deploy_config(%__MODULE__{} = app) do
    release_path = app.release_path || default_release_path(app.slug)
    basename = release_path |> Path.basename()

    %{
      release_path: release_path,
      systemd_unit: app.systemd_unit || default_systemd_unit(app.slug),
      release_name: release_name(app.slug),
      env_file: "/etc/#{basename}/env"
    }
  end

  defp put_deploy_defaults(changeset) do
    case get_field(changeset, :slug) do
      slug when is_binary(slug) and slug != "" ->
        changeset
        |> put_default(:systemd_unit, default_systemd_unit(slug))
        |> put_default(:release_path, default_release_path(slug))

      _ ->
        changeset
    end
  end

  defp put_default(changeset, field, default) do
    if get_field(changeset, field) in [nil, ""] do
      put_change(changeset, field, default)
    else
      changeset
    end
  end

  defp put_default_webhook_secret(changeset) do
    if get_field(changeset, :webhook_secret) in [nil, ""] do
      put_change(changeset, :webhook_secret, Base.url_encode64(:crypto.strong_rand_bytes(24)))
    else
      changeset
    end
  end

  defp cast_runtime_packages(changeset) do
    case get_change(changeset, :runtime_packages_text) do
      nil ->
        changeset

      text ->
        packages =
          text
          |> String.split(~r/[\s,]+/, trim: true)
          |> Enum.reject(&(&1 == ""))

        changeset
        |> put_change(:runtime_apt_packages, packages)
        |> delete_change(:runtime_packages_text)
    end
  end

  defp put_runtime_packages_text(changeset) do
    packages = get_field(changeset, :runtime_apt_packages) || []

    put_change(
      changeset,
      :runtime_packages_text,
      Enum.join(packages, "\n")
    )
  end
end
