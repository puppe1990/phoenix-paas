defmodule PhoenixPaas.Servers.Server do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias PhoenixPaas.Encrypted

  schema "servers" do
    field :name, :string
    field :host_ip, :string
    field :ssh_user, :string, default: "ubuntu"
    field :region, :string, default: "us-east-1"
    field :ssh_private_key_encrypted, Encrypted.Binary
    field :ssh_private_key, :string, virtual: true
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
      :ssh_private_key,
      :aws_instance_name
    ])
    |> validate_required([:name, :host_ip, :ssh_user, :region])
    |> validate_length(:name, min: 1, max: 160)
    |> validate_ipv4(:host_ip)
    |> maybe_put_ssh_key()
    |> unique_constraint(:name)
  end

  defp maybe_put_ssh_key(changeset) do
    case get_change(changeset, :ssh_private_key) do
      key when is_binary(key) and key != "" ->
        changeset
        |> put_change(:ssh_private_key_encrypted, String.trim_trailing(key))
        |> delete_change(:ssh_private_key)

      _ ->
        delete_change(changeset, :ssh_private_key)
    end
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
