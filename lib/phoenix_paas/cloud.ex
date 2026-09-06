defmodule PhoenixPaas.Cloud do
  @moduledoc """
  Dispatches instance operations to Lightsail or Hetzner.
  """

  alias PhoenixPaas.AWS.Lightsail
  alias PhoenixPaas.Hetzner
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Servers.Server

  def sync_specs(%Server{} = server) do
    with {:ok, name} <- instance_name(server),
         {:ok, spec} <- get_instance(server, name),
         {:ok, updated} <- apply_spec(server, spec) do
      {:ok, updated}
    end
  end

  def list_resize_options(%Server{} = server) do
    case list_bundles(server) do
      {:ok, bundles} ->
        Enum.reject(bundles, &(&1.bundle_id == server.bundle_id))

      {:error, _} ->
        []
    end
  end

  def resize_bundle(%Server{} = server, bundle_id) do
    with {:ok, name} <- instance_name(server),
         :ok <- change_bundle(server, name, bundle_id),
         {:ok, updated} <- sync_specs(server) do
      {:ok, updated}
    end
  end

  def provider(%Server{provider: provider}) when is_binary(provider) and provider != "",
    do: provider

  def provider(_), do: "lightsail"

  def hetzner?(%Server{} = server), do: provider(server) == "hetzner"

  def format_price(%Server{provider: "hetzner", monthly_price_usd: %Decimal{} = price}) do
    "€#{Decimal.round(price, 2)}/mo"
  end

  def format_price(%Server{} = server), do: Server.format_price(server)

  def provider_label("hetzner"), do: "Hetzner Cloud"
  def provider_label(_), do: "AWS Lightsail"

  defp get_instance(%Server{} = server, name) do
    if hetzner?(server) do
      Hetzner.get_instance(server.region, name)
    else
      Lightsail.get_instance(server.region, name)
    end
  end

  defp list_bundles(%Server{} = server) do
    if hetzner?(server) do
      Hetzner.list_bundles(server.region)
    else
      Lightsail.list_bundles(server.region)
    end
  end

  defp change_bundle(%Server{} = server, name, bundle_id) do
    if hetzner?(server) do
      Hetzner.change_bundle(server.region, name, bundle_id)
    else
      Lightsail.change_bundle(server.region, name, bundle_id)
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
end
