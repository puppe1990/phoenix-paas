defmodule PhoenixPaas.Seeds do
  @moduledoc """
  Idempotent database seeds for local and production bootstrap.
  """

  alias PhoenixPaas.{Apps, Repo, Servers}
  alias PhoenixPaas.Accounts

  import Ecto.Query

  @matheus_email "matheus.puppe@gmail.com"

  @doc """
  Seeds the matheus owner account, Gestão Bem tenant, and Trip Planner app.
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
          existing

        nil ->
          ssh_key =
            Keyword.get(
              opts,
              :ssh_key_path,
              System.get_env(
                "SEED_SSH_KEY_PATH",
                Path.expand("~/.ssh/lightsail-default-key-us-east-1.pem")
              )
            )

          attrs = %{
            name: "trip-lightsail",
            host_ip: "100.59.80.29",
            ssh_user: "ubuntu",
            region: "us-east-1"
          }

          attrs =
            if is_binary(ssh_key) and File.exists?(ssh_key) do
              Map.put(attrs, :ssh_private_key, File.read!(ssh_key))
            else
              attrs
            end

          {:ok, server} = Servers.create_server(scope, attrs)
          server
      end

    case Apps.get_app_by_repo("puppe1990/trip-planner-ia-phx") do
      %Apps.App{tenant_id: ^tenant_id} ->
        :ok

      %Apps.App{} = app ->
        app
        |> Ecto.Changeset.change(%{tenant_id: tenant_id, server_id: server.id})
        |> Repo.update!()

      nil ->
        {:ok, _app} =
          Apps.create_app(scope, %{
            name: "Trip Planner",
            slug: "trip-planner",
            github_repo: "puppe1990/trip-planner-ia-phx",
            branch: "main",
            host: "trip.gestaobem.com",
            server_id: server.id
          })
    end

    {:ok, %{user: user, scope: scope, server: server}}
  end
end
