defmodule PhoenixPaas.Hetzner.Stub do
  @moduledoc """
  Offline Hetzner client for dev/test without an API token.
  """
  @behaviour PhoenixPaas.Hetzner

  alias PhoenixPaas.AWS.Lightsail.InstanceSpec
  alias PhoenixPaas.Hetzner.Catalog

  @impl true
  def get_instance(_location, instance_name) do
    bundle_id = bundle_for_instance(instance_name)
    bundle = Catalog.find_bundle(bundle_id)

    {:ok,
     %InstanceSpec{
       bundle_id: bundle.bundle_id,
       bundle_name: bundle.bundle_name,
       cpu_count: bundle.cpu_count,
       ram_mb: bundle.ram_mb,
       disk_gb: bundle.disk_gb,
       status: "running",
       blueprint_name: "Ubuntu 24.04",
       monthly_price_usd: bundle.monthly_price_usd
     }}
  end

  @impl true
  def list_bundles(_location), do: {:ok, Catalog.all_bundles()}

  @impl true
  def change_bundle(_location, instance_name, bundle_id) do
    if Catalog.find_bundle(bundle_id) do
      :ets.insert(stub_table(), {instance_name, bundle_id})
      :ok
    else
      {:error, :invalid_bundle}
    end
  end

  defp bundle_for_instance(instance_name) do
    case :ets.lookup(stub_table(), instance_name) do
      [{^instance_name, bundle_id}] -> bundle_id
      _ -> "cx33"
    end
  end

  defp stub_table do
    case :ets.whereis(:phoenix_paas_hetzner_stub) do
      :undefined ->
        :ets.new(:phoenix_paas_hetzner_stub, [:named_table, :public, :set])

      tid ->
        tid
    end
  end
end
