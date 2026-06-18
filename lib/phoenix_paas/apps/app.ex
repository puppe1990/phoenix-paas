defmodule PhoenixPaas.Apps.App do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

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
      :server_id
    ])
    |> validate_required([:name, :slug, :github_repo, :host, :server_id])
    |> validate_format(:github_repo, ~r/^[^\/]+\/[^\/]+$/, message: "must be owner/repo")
    |> validate_number(:port, greater_than: 0, less_than: 65_536)
    |> unique_constraint(:slug)
    |> unique_constraint(:github_repo)
    |> foreign_key_constraint(:server_id)
    |> put_default_webhook_secret()
  end

  defp put_default_webhook_secret(changeset) do
    if get_field(changeset, :webhook_secret) in [nil, ""] do
      put_change(changeset, :webhook_secret, Base.url_encode64(:crypto.strong_rand_bytes(24)))
    else
      changeset
    end
  end
end
