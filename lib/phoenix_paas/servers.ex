defmodule PhoenixPaas.Servers do
  @moduledoc """
  Manages deploy target servers (Lightsail VMs).
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Accounts.Scope
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Servers.Server

  def list_servers(%Scope{tenant: tenant}) do
    Repo.all(
      from s in Server,
        where: s.tenant_id == ^tenant.id,
        order_by: [asc: s.name]
    )
  end

  def get_server!(%Scope{tenant: tenant}, id) do
    Repo.one!(
      from s in Server,
        where: s.tenant_id == ^tenant.id and s.id == ^id
    )
  end

  def create_server(%Scope{tenant: tenant}, attrs) do
    attrs = Map.put(stringify_keys(attrs), "tenant_id", tenant.id)

    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  def change_server(server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  def ssh_key_configured?(%Server{} = server) do
    is_binary(server.ssh_private_key_encrypted) and server.ssh_private_key_encrypted != ""
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
