defmodule PhoenixPaas.Servers.Server do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "servers" do
    field :name, :string
    field :host_ip, :string
    field :ssh_user, :string, default: "ubuntu"
    field :region, :string, default: "us-east-1"
    field :ssh_private_key_encrypted, :binary
    field :aws_instance_name, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(server, attrs) do
    server
    |> cast(attrs, [
      :name,
      :host_ip,
      :ssh_user,
      :region,
      :ssh_private_key_encrypted,
      :aws_instance_name
    ])
    |> validate_required([:name, :host_ip, :ssh_user, :region])
    |> validate_length(:name, min: 1, max: 160)
    |> validate_ipv4(:host_ip)
    |> unique_constraint(:name)
  end

  defp validate_ipv4(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      case :inet.parse_address(String.to_charlist(value)) do
        {:ok, {_, _, _, _}} -> []
        _ -> [{field, "is invalid"}]
      end
    end)
  end
end
