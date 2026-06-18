defmodule PhoenixPaas.Apps.AppEnvVar do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixPaas.Apps.App
  alias PhoenixPaas.Encrypted

  schema "app_env_vars" do
    field :key, :string
    field :value, Encrypted.Binary

    belongs_to :app, App

    timestamps(type: :utc_datetime)
  end

  def changeset(env_var, attrs) do
    env_var
    |> cast(attrs, [:key, :value, :app_id])
    |> validate_required([:key, :value, :app_id])
    |> validate_format(:key, ~r/^[A-Z][A-Z0-9_]*$/, message: "must be UPPER_SNAKE_CASE")
    |> unique_constraint([:app_id, :key])
    |> foreign_key_constraint(:app_id)
  end
end
