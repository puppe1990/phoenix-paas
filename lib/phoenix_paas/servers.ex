defmodule PhoenixPaas.Servers do
  @moduledoc """
  Manages deploy target servers (Lightsail and Hetzner VMs).
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Accounts.Scope
  alias PhoenixPaas.Cloud
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

  def update_host_ip(%Server{} = server, host_ip) when is_binary(host_ip) do
    server
    |> Server.changeset(%{host_ip: host_ip})
    |> Repo.update()
  end

  def change_server(server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end

  def ssh_key_configured?(%Server{} = server) do
    is_binary(server.ssh_private_key_encrypted) and server.ssh_private_key_encrypted != ""
  end

  def sync_specs(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server)
      when tenant_id == tenant.id do
    sync_specs(server)
  end

  def sync_specs(%Scope{}, %Server{}), do: {:error, :unauthorized}

  def sync_specs(%Server{} = server) do
    Cloud.sync_specs(server)
  end

  def list_resize_options(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server)
      when tenant_id == tenant.id do
    list_resize_options(server)
  end

  def list_resize_options(%Scope{}, %Server{}), do: []

  def list_resize_options(%Server{} = server) do
    Cloud.list_resize_options(server)
  end

  def resize_bundle(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server, bundle_id)
      when tenant_id == tenant.id do
    resize_bundle(server, bundle_id)
  end

  def resize_bundle(%Scope{}, %Server{}, _bundle_id), do: {:error, :unauthorized}

  def resize_bundle(%Server{} = server, bundle_id) do
    Cloud.resize_bundle(server, bundle_id)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
