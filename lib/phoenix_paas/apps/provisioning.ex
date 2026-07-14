defmodule PhoenixPaas.Apps.Provisioning do
  @moduledoc false

  alias PhoenixPaas.Apps.App
  alias PhoenixPaas.Servers.Server

  @host_domain "gestaobem.com"

  @known_presets %{
    "puppe1990/trip-planner-ia-phx" => %{
      name: "Trip Planner",
      slug: "trip-planner",
      host: "trip.gestaobem.com",
      port: 4000
    },
    "puppe1990/rapid-tools" => %{
      name: "RapidTools",
      slug: "rapid-tools",
      host: "tools.gestaobem.com",
      port: 4001,
      systemd_unit: "rapid_tools",
      release_path: "/opt/rapid_tools"
    },
    "puppe1990/OpenDrive" => %{
      name: "OpenDrive",
      slug: "open-drive",
      host: "drive.gestaobem.com",
      port: 4002,
      systemd_unit: "open_drive",
      release_path: "/opt/open_drive"
    },
    "puppe1990/mass-transcriptor-phoenix" => %{
      name: "Mass Transcriptor",
      slug: "mass-transcriptor",
      host: "transcribe.gestaobem.com",
      port: 4003,
      systemd_unit: "mass_transcriptor",
      release_path: "/opt/mass_transcriptor"
    },
    "puppe1990/phoenix_tts" => %{
      name: "Phoenix TTS",
      slug: "phoenix-tts",
      host: "tts.gestaobem.com",
      port: 4004,
      systemd_unit: "phoenix_tts",
      release_path: "/opt/phoenix_tts"
    },
    "gestao-bem/catalog_platform" => %{
      name: "Catálogo",
      slug: "catalogo",
      host: "loja.gestaobem.com",
      port: 4000,
      systemd_unit: "catalog_platform",
      release_path: "/opt/catalog_platform",
      server_name: "catalogo-lightsail"
    },
    "puppe1990/controle-agente-viagens" => %{
      name: "VipTravel",
      slug: "controle-agente-viagens",
      host: "vip.gestaobem.com",
      port: 4007,
      systemd_unit: "controle_agente_viagens",
      release_path: "/opt/controle_agente_viagens_phx"
    },
    "puppe1990/campanha-ops" => %{
      name: "Campanha",
      slug: "campanha",
      host: "campanha.gestaobem.com",
      port: 4000,
      systemd_unit: "campanha",
      release_path: "/opt/campanha",
      server_name: "campanha-lightsail"
    }
  }

  @doc """
  Returns preset attrs for registering an app from a GitHub repo slug.
  """
  def preset_from_repo(github_repo, servers \\ []) when is_list(servers) do
    github_repo = String.trim(github_repo)

    if github_repo == "" do
      %{}
    else
      github_repo
      |> then(&Map.get(@known_presets, &1, derive_preset(&1)))
      |> Map.put(:github_repo, github_repo)
      |> Map.put_new(:branch, "main")
      |> put_server_id(servers)
      |> put_deploy_defaults()
      |> stringify_keys()
    end
  end

  @doc """
  Merges preset attrs into form params when a repository is selected.

  Preset values win for auto fields unless `advanced` is enabled in params.
  """
  def apply_preset(params, servers) when is_map(params) do
    repo = param(params, "github_repo")

    if repo in [nil, ""] do
      params
    else
      preset = preset_from_repo(repo, servers)
      advanced? = param(params, "advanced") in ["true", "on", true]

      if advanced? do
        params
      else
        Map.merge(params, preset)
      end
    end
  end

  defp derive_preset(github_repo) do
    slug = slug_from_repo(github_repo)

    %{
      name: humanize_slug(slug),
      slug: slug,
      host: "#{slug}.#{@host_domain}",
      port: 4000
    }
  end

  defp slug_from_repo(github_repo) do
    github_repo
    |> String.split("/", parts: 2)
    |> List.last()
    |> String.downcase()
    |> String.replace("_", "-")
    |> String.replace(~r/[^a-z0-9-]+/u, "-")
    |> String.trim("-")
  end

  defp humanize_slug(slug) do
    slug
    |> String.split("-", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp put_server_id(attrs, servers) do
    server_id =
      case Map.get(attrs, :server_name) do
        name when is_binary(name) ->
          servers
          |> Enum.find_value(fn %Server{id: id, name: server_name} ->
            if server_name == name, do: id
          end)
          |> Kernel.||(default_server_id(servers))

        _ ->
          default_server_id(servers)
      end

    attrs
    |> Map.delete(:server_name)
    |> Map.put(:server_id, server_id)
  end

  defp default_server_id([]), do: nil

  defp default_server_id([%Server{id: id} | _]), do: id

  defp put_deploy_defaults(%{slug: slug} = attrs) when is_binary(slug) and slug != "" do
    attrs
    |> Map.put_new(:systemd_unit, App.default_systemd_unit(slug))
    |> Map.put_new(:release_path, App.default_release_path(slug))
  end

  defp put_deploy_defaults(attrs), do: attrs

  defp param(params, key) do
    Map.get(params, key) || Map.get(params, String.to_existing_atom(key))
  rescue
    ArgumentError -> Map.get(params, key)
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
