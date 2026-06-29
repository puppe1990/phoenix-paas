defmodule PhoenixPaas.Seeds do
  @moduledoc """
  Idempotent database seeds for local and production bootstrap.
  """

  alias PhoenixPaas.{Apps, Repo, Servers}
  alias PhoenixPaas.Accounts

  import Ecto.Query

  @matheus_email "matheus.puppe@gmail.com"

  @doc """
  Seeds the matheus owner account, Gestão Bem tenant, Trip Planner, and RapidTools apps.
  Safe to run multiple times.
  """
  def run(opts \\ []) do
    email = Keyword.get(opts, :email, @matheus_email)
    password = Keyword.get(opts, :password, System.get_env("SEED_USER_PASSWORD"))

    user =
      case Accounts.get_user_by_email(email) do
        %{} = existing ->
          existing

        nil ->
          {:ok, user} = Accounts.register_user(%{email: email})
          user
      end

    user =
      if password do
        {:ok, {user, _tokens}} = Accounts.update_user_password(user, %{password: password})
        user
      else
        user
      end

    scope =
      Accounts.ensure_tenant_for_user(user, %{
        name: "Gestão Bem",
        slug: "gestao-bem"
      })

    tenant_id = scope.tenant.id

    server =
      case Repo.one(from s in Servers.Server, where: s.tenant_id == ^tenant_id, limit: 1) do
        %Servers.Server{} = existing ->
          maybe_backfill_server_ssh_key(existing, opts)

        nil ->
          {:ok, server} = Servers.create_server(scope, server_seed_attrs(opts))
          server
      end

    seed_app(scope, server, tenant_id, %{
      name: "Trip Planner",
      slug: "trip-planner",
      github_repo: "puppe1990/trip-planner-ia-phx",
      branch: "main",
      host: "trip.gestaobem.com",
      port: 4000
    })

    seed_app(scope, server, tenant_id, %{
      name: "RapidTools",
      slug: "rapid-tools",
      github_repo: "puppe1990/rapid-tools",
      branch: "main",
      host: "tools.gestaobem.com",
      port: 4001,
      systemd_unit: "rapid_tools",
      release_path: "/opt/rapid_tools"
    })

    seed_app(scope, server, tenant_id, %{
      name: "OpenDrive",
      slug: "open-drive",
      github_repo: "puppe1990/OpenDrive",
      branch: "main",
      host: "drive.gestaobem.com",
      port: 4002,
      systemd_unit: "open_drive",
      release_path: "/opt/open_drive"
    })

    {:ok, %{user: user, scope: scope, server: server}}
  end

  defp seed_app(scope, server, tenant_id, attrs) do
    repo = Map.fetch!(attrs, :github_repo)

    app =
      case Apps.get_app_by_repo(repo) do
        %Apps.App{tenant_id: ^tenant_id} = app ->
          maybe_update_app(app, server, tenant_id, attrs)

        %Apps.App{} = app ->
          app
          |> Ecto.Changeset.change(app_seed_attrs(server, tenant_id, attrs))
          |> Repo.update!()

        nil ->
          {:ok, app, _webhook_status} =
            Apps.create_app(scope, Map.put(attrs, :server_id, server.id))

          app
      end

    Apps.sync_github_webhook(app)
    app
  end

  defp maybe_update_app(app, server, tenant_id, attrs) do
    changes = app_seed_attrs(server, tenant_id, attrs)

    if Enum.any?(changes, fn {key, value} -> Map.get(app, key) != value end) do
      app
      |> Ecto.Changeset.change(changes)
      |> Repo.update!()
    else
      app
    end
  end

  defp server_seed_attrs(opts) do
    attrs = %{
      name: "trip-lightsail",
      host_ip: "100.59.80.29",
      ssh_user: "ubuntu",
      region: "us-east-1"
    }

    case read_ssh_key(opts) do
      nil -> attrs
      key -> Map.put(attrs, :ssh_private_key, key)
    end
  end

  defp maybe_backfill_server_ssh_key(%Servers.Server{} = server, opts) do
    if Servers.ssh_key_configured?(server) do
      server
    else
      case read_ssh_key(opts) do
        nil ->
          server

        key ->
          server
          |> Servers.Server.changeset(%{ssh_private_key: key})
          |> Repo.update!()
      end
    end
  end

  defp read_ssh_key(opts) do
    path =
      Keyword.get(
        opts,
        :ssh_key_path,
        System.get_env(
          "SEED_SSH_KEY_PATH",
          Path.expand("~/.ssh/lightsail-default-key-us-east-1.pem")
        )
      )

    if is_binary(path) and File.exists?(path) do
      File.read!(path)
    end
  end

  defp app_seed_attrs(server, tenant_id, attrs) do
    attrs
    |> Map.take([
      :name,
      :slug,
      :github_repo,
      :branch,
      :host,
      :port,
      :systemd_unit,
      :release_path
    ])
    |> Map.put(:tenant_id, tenant_id)
    |> Map.put(:server_id, server.id)
  end
end
