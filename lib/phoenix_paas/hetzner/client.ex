defmodule PhoenixPaas.Hetzner.Client do
  @moduledoc """
  Hetzner Cloud API client using Req.
  """
  @behaviour PhoenixPaas.Hetzner

  alias PhoenixPaas.AWS.Lightsail.InstanceSpec
  alias PhoenixPaas.Hetzner.Catalog

  @base_url "https://api.hetzner.cloud/v1"

  @impl true
  def get_instance(_location, instance_name) do
    case request(:get, "/servers", name: instance_name) do
      {:ok, %{"servers" => [%{} = server | _]}} -> {:ok, map_server(server)}
      {:ok, %{"servers" => []}} -> {:error, :not_found}
      {:ok, _} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list_bundles(_location) do
    {:ok, Catalog.all_bundles()}
  end

  @impl true
  def change_bundle(_location, instance_name, bundle_id) do
    with {:ok, server_id} <- server_id_by_name(instance_name),
         {:ok, _} <-
           request(:post, "/servers/#{server_id}/actions/change_type", %{
             server_type: bundle_id,
             upgrade_disk: true
           }) do
      :ok
    end
  end

  def map_server(server) when is_map(server) do
    type = server["server_type"] || %{}
    bundle_id = type["name"]
    catalog = Catalog.find_bundle(bundle_id)
    image = server["image"] || %{}

    %InstanceSpec{
      bundle_id: bundle_id,
      bundle_name: (catalog && catalog.bundle_name) || type["description"] || bundle_id,
      cpu_count: type["cores"] || (catalog && catalog.cpu_count) || 1,
      ram_mb: ram_mb(type["memory"]) || (catalog && catalog.ram_mb) || 1024,
      disk_gb: type["disk"] || (catalog && catalog.disk_gb) || 20,
      status: server["status"] || "unknown",
      blueprint_name: image["description"] || image["name"] || "—",
      monthly_price_usd: monthly_price(type, catalog)
    }
  end

  def public_ipv4(server) when is_map(server) do
    get_in(server, ["public_net", "ipv4", "ip"])
  end

  defp server_id_by_name(instance_name) do
    case request(:get, "/servers", name: instance_name) do
      {:ok, %{"servers" => [%{"id" => id} | _]}} -> {:ok, id}
      {:ok, %{"servers" => []}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp request(method, path, params) when method in [:get] and is_list(params) do
    case Req.request(
           method: method,
           url: @base_url <> path,
           headers: auth_headers(),
           params: params,
           receive_timeout: 60_000
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        decode_body(body)

      {:ok, %{status: status, body: body}} ->
        {:error, {:hetzner, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(method, path, body) when is_map(body) do
    case Req.request(
           method: method,
           url: @base_url <> path,
           headers: auth_headers(),
           json: body,
           receive_timeout: 60_000
         ) do
      {:ok, %{status: status, body: response_body}} when status in 200..299 ->
        decode_body(response_body)

      {:ok, %{status: status, body: response_body}} ->
        {:error, {:hetzner, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_body(body) when is_binary(body), do: Jason.decode(body)
  defp decode_body(body) when is_map(body), do: {:ok, body}

  defp auth_headers do
    [{"authorization", "Bearer #{api_token()}"}]
  end

  defp api_token do
    System.get_env("HCLOUD_TOKEN") ||
      System.get_env("HETZNER_API_TOKEN") ||
      raise "HCLOUD_TOKEN or HETZNER_API_TOKEN is missing"
  end

  defp ram_mb(gb) when is_number(gb), do: round(gb * 1024)
  defp ram_mb(_), do: nil

  defp monthly_price(%{"prices" => prices}, catalog) when is_list(prices) do
    gross =
      prices
      |> Enum.find_value(fn price ->
        get_in(price, ["price_monthly", "gross"])
      end)

    parse_decimal(gross) || (catalog && catalog.monthly_price_usd) || Decimal.new("0")
  end

  defp monthly_price(_type, catalog) do
    (catalog && catalog.monthly_price_usd) || Decimal.new("0")
  end

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp parse_decimal(_), do: nil
end
