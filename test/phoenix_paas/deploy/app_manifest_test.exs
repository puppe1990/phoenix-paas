defmodule PhoenixPaas.Deploy.AppManifestTest do
  use PhoenixPaas.DataCase, async: true

  alias PhoenixPaas.Deploy.AppManifest
  alias PhoenixPaas.TenancyFixtures

  setup do
    scope = TenancyFixtures.scope_fixture()
    server = TenancyFixtures.server_fixture(scope)

    {:ok, app, _webhook_status} =
      PhoenixPaas.Apps.create_app(scope, %{
        name: "Catálogo",
        slug: "catalogo",
        github_repo: "gestao-bem/catalog_platform",
        host: "loja.gestaobem.com",
        port: 4000,
        server_id: server.id
      })

    tmp = System.tmp_dir!()
    repo_path = Path.join(tmp, "catalog_manifest_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(repo_path, ".phoenix_paas"))

    File.write!(
      Path.join(repo_path, ".phoenix_paas/deploy.json"),
      ~s({
        "solo_server": true,
        "caddyfile": "deploy/Caddyfile",
        "caddy_mode": "replace",
        "memory_max_mb": 1024
      })
    )

    on_exit(fn -> File.rm_rf(repo_path) end)

    %{app: app, server: server, repo_path: repo_path}
  end

  test "resolve reads deploy.json from repo", %{app: app, repo_path: repo_path} do
    manifest = AppManifest.resolve(repo_path, app)

    assert manifest.solo_server
    assert manifest.caddy_mode == "replace"
    assert manifest.caddyfile == "deploy/Caddyfile"
    assert manifest.memory_max_mb == 1024
    assert manifest.domain_checklist?
  end

  test "validate_for_server rejects solo app on shared server", %{
    app: app,
    server: server,
    repo_path: repo_path
  } do
    manifest = AppManifest.resolve(repo_path, app)

    assert {:error, _} = AppManifest.validate_for_server(manifest, server, [app], app)
  end

  test "validate_for_server accepts solo app on dedicated server", %{
    app: app,
    server: server,
    repo_path: repo_path
  } do
    server = %{server | deploy_mode: "dedicated"}
    manifest = AppManifest.resolve(repo_path, app)

    assert :ok = AppManifest.validate_for_server(manifest, server, [app], app)
  end
end
