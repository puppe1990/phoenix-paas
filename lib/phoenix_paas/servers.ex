defmodule PhoenixPaas.Servers do
  @moduledoc """
  Manages deploy target servers (Lightsail VMs).
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Accounts.Scope
  alias PhoenixPaas.AWS.Lightsail
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

  def sync_specs(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server)
      when tenant_id == tenant.id do
    sync_specs(server)
  end

  def sync_specs(%Scope{}, %Server{}), do: {:error, :unauthorized}

  def sync_specs(%Server{} = server) do
    with {:ok, instance_name} <- instance_name(server),
         {:ok, spec} <- Lightsail.get_instance(server.region, instance_name),
         {:ok, updated} <- apply_spec(server, spec) do
      {:ok, updated}
    end
  end

  def list_resize_options(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server)
      when tenant_id == tenant.id do
    list_resize_options(server)
  end

  def list_resize_options(%Scope{}, %Server{}), do: []

  def list_resize_options(%Server{} = server) do
    case Lightsail.list_bundles(server.region) do
      {:ok, bundles} ->
        Enum.reject(bundles, &(&1.bundle_id == server.bundle_id))

      {:error, _} ->
        []
    end
  end

  def resize_bundle(%Scope{tenant: tenant}, %Server{tenant_id: tenant_id} = server, bundle_id)
      when tenant_id == tenant.id do
    resize_bundle(server, bundle_id)
  end

  def resize_bundle(%Scope{}, %Server{}, _bundle_id), do: {:error, :unauthorized}

  def resize_bundle(%Server{} = server, bundle_id) do
    with {:ok, instance_name} <- instance_name(server),
         :ok <- Lightsail.change_bundle(server.region, instance_name, bundle_id),
         {:ok, updated} <- sync_specs(server) do
      {:ok, updated}
    end
  end

  defp instance_name(%Server{aws_instance_name: name})
       when is_binary(name) and name != "",
       do: {:ok, name}

  defp instance_name(_), do: {:error, :missing_instance_name}

  defp apply_spec(server, spec) do
    server
    |> Server.changeset(%{
      bundle_id: spec.bundle_id,
      bundle_name: spec.bundle_name,
      cpu_count: spec.cpu_count,
      ram_mb: spec.ram_mb,
      disk_gb: spec.disk_gb,
      instance_status: spec.status,
      blueprint_name: spec.blueprint_name,
      monthly_price_usd: spec.monthly_price_usd,
      specs_synced_at: DateTime.utc_now(:second)
    })
    |> Repo.update()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
