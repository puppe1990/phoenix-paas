# Register Campanha Ops on the panel and sync GitHub webhook:
#   DEPLOY_RUNNER=ssh mix run --no-start priv/scripts/setup_campanha.exs
#
# On production panel:
#   bin/phoenix_paas rpc "Code.eval_file('priv/scripts/setup_campanha.exs')"

for app <- [:crypto, :ecto_sql, :ecto_sqlite3, :cloak, :cloak_ecto, :finch, :req] do
  {:ok, _} = Application.ensure_all_started(app)
end

for child <- [PhoenixPaas.Repo, PhoenixPaas.Vault] do
  {:ok, _} = child.start_link()
end

webhook_host =
  System.get_env("PAAS_WEBHOOK_HOST") ||
    System.get_env("PHX_HOST") ||
    "paas.gestaobem.com"

Application.put_env(:phoenix_paas, PhoenixPaasWeb.Endpoint,
  server: false,
  url: [host: webhook_host, port: 443, scheme: "https"]
)

{:ok, _} = PhoenixPaasWeb.Endpoint.start_link()

alias PhoenixPaas.{Accounts, Apps, Repo, Servers}
import Ecto.Query

email = "matheus.puppe@gmail.com"
user = Accounts.get_user_by_email(email) || raise "user not found: #{email}"
scope = Accounts.ensure_scope_for_user(user)
tenant_id = scope.tenant.id

host_ip = System.get_env("CAMPANHA_SERVER_IP") || "52.0.157.89"

ssh_key =
  case System.get_env("SEED_SSH_KEY_PATH") do
    path when is_binary(path) and path != "" ->
      if File.exists?(path), do: File.read!(path), else: nil

    _ ->
      nil
  end

ssh_key =
  ssh_key ||
    case Repo.one(from s in Servers.Server, where: s.name == "trip-lightsail", limit: 1) do
      %Servers.Server{ssh_private_key_encrypted: key} when is_binary(key) and key != "" -> key
      _ -> nil
    end

server_attrs =
  %{
    name: "campanha-lightsail",
    host_ip: host_ip,
    ssh_user: "ubuntu",
    region: "us-east-1",
    deploy_mode: "dedicated",
    aws_instance_name: "campanha-lightsail"
  }
  |> then(fn attrs ->
    if is_binary(ssh_key), do: Map.put(attrs, :ssh_private_key, ssh_key), else: attrs
  end)

server =
  case Repo.one(
         from s in Servers.Server,
           where: s.tenant_id == ^tenant_id and s.name == "campanha-lightsail",
           limit: 1
       ) do
    %Servers.Server{} = existing ->
      existing
      |> Servers.Server.changeset(server_attrs)
      |> Repo.update!()

    nil ->
      {:ok, server} = Servers.create_server(scope, server_attrs)
      server
  end

app_attrs = %{
  name: "Campanha",
  slug: "campanha",
  github_repo: "puppe1990/campanha-ops",
  branch: "main",
  host: "campanha.gestaobem.com",
  port: 4000,
  systemd_unit: "campanha",
  release_path: "/opt/campanha",
  auto_deploy: true,
  server_id: server.id
}

app =
  case Apps.get_app_by_repo("puppe1990/campanha-ops") do
    nil ->
      {:ok, app, _status} = Apps.create_app(scope, app_attrs)
      Apps.get_app!(scope, app.id)

    %{} = existing ->
      existing
      |> Ecto.Changeset.change(Map.put(app_attrs, :tenant_id, tenant_id))
      |> Repo.update!()
  end

env = %{
  "PHX_SERVER" => "true",
  "PORT" => "4000",
  "PHX_HOST" => "campanha.gestaobem.com",
  "POOL_SIZE" => "5",
  "SECRET_KEY_BASE" => System.get_env("CAMPANHA_SECRET_KEY_BASE"),
  "TURSO_DATABASE_URL" => System.get_env("CAMPANHA_TURSO_DATABASE_URL"),
  "TURSO_AUTH_TOKEN" => System.get_env("CAMPANHA_TURSO_AUTH_TOKEN")
}

for {key, value} <- env, is_binary(value) and value != "" do
  {:ok, _} = Apps.put_env_var(app, key, value)
end

{webhook_status, _} = Apps.sync_github_webhook(app)

IO.inspect(
  %{
    app_id: app.id,
    slug: app.slug,
    host: app.host,
    server_ip: server.host_ip,
    webhook: webhook_status,
    auto_deploy: app.auto_deploy
  },
  label: "campanha_setup"
)