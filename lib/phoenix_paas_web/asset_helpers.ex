defmodule PhoenixPaasWeb.AssetHelpers do
  @moduledoc false

  @doc """
  Returns a cache-busted asset path in development so the browser always
  picks up the latest Tailwind/esbuild output after a rebuild.
  """
  def asset_path(path) when is_binary(path) do
    base = Phoenix.VerifiedRoutes.static_path(PhoenixPaasWeb.Endpoint, path)

    if dev_asset_versioning?() do
      base <> "?" <> dev_asset_query(path)
    else
      base
    end
  end

  defp dev_asset_versioning? do
    Application.get_env(:phoenix_paas, PhoenixPaasWeb.Endpoint)[:code_reloader]
  end

  defp dev_asset_query("/assets/" <> relative) do
    priv_assets = Application.app_dir(:phoenix_paas, "priv/static/assets")
    file = Path.join(priv_assets, relative)

    stamp =
      case File.stat(file) do
        {:ok, %{mtime: mtime, size: size}} ->
          {{y, m, d}, {h, min, s}} = mtime
          "#{y}#{m}#{d}#{h}#{min}#{s}-#{size}"

        _ ->
          Integer.to_string(System.system_time(:second))
      end

    "t=" <> stamp
  end
end
