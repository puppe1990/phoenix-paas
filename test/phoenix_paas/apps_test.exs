defmodule PhoenixPaas.AppsTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.Apps
  alias PhoenixPaas.TenancyFixtures

  setup do
    scope = TenancyFixtures.scope_fixture()
    server = TenancyFixtures.server_fixture(scope)
    %{scope: scope, server: server}
  end

  describe "create_app/2" do
    test "persists app linked to server", %{scope: scope, server: server} do
      attrs = %{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      }

      assert {:ok, app} = Apps.create_app(scope, attrs)
      assert app.tenant_id == scope.tenant.id
      assert app.systemd_unit == "trip_planner_ia"
      assert app.release_path == "/opt/trip_planner_ia"
    end

    test "requires github_repo, host, and server_id", %{scope: scope, server: server} do
      assert {:error, changeset} =
               Apps.create_app(scope, %{name: "X", slug: "x", server_id: server.id})

      assert "can't be blank" in errors_on(changeset).github_repo
      assert "can't be blank" in errors_on(changeset).host
    end
  end

  describe "env_map/1" do
    test "includes PHX_HOST and stored env vars", %{scope: scope, server: server} do
      {:ok, app} =
        Apps.create_app(scope, %{
          name: "Trip Planner",
          slug: "trip-planner",
          github_repo: "puppe1990/trip-planner-ia-phx",
          host: "trip.gestaobem.com",
          server_id: server.id
        })

      {:ok, _} = Apps.put_env_var(app, "SECRET_KEY_BASE", "super-secret")
      {:ok, _} = Apps.put_env_var(app, "GEMINI_API_KEY", "gemini-key")

      assert Apps.env_map(app) == %{
               "PHX_HOST" => "trip.gestaobem.com",
               "SECRET_KEY_BASE" => "super-secret",
               "GEMINI_API_KEY" => "gemini-key"
             }
    end
  end
end
