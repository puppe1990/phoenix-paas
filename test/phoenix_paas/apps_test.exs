defmodule PhoenixPaas.AppsTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.{Apps, Servers}

  setup do
    {:ok, server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    %{server: server}
  end

  describe "create_app/1" do
    test "persists app linked to server", %{server: server} do
      attrs = %{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      }

      assert {:ok, app} = Apps.create_app(attrs)
      assert app.github_repo == "puppe1990/trip-planner-ia-phx"
      assert app.host == "trip.gestaobem.com"
      assert app.server_id == server.id
      assert app.branch == "main"
      assert app.auto_deploy == true
    end

    test "requires github_repo, host, and server_id", %{server: server} do
      assert {:error, changeset} =
               Apps.create_app(%{name: "X", slug: "x", server_id: server.id})

      assert "can't be blank" in errors_on(changeset).github_repo
      assert "can't be blank" in errors_on(changeset).host
    end
  end

  describe "env_map/1" do
    test "includes PHX_HOST and stored env vars", %{server: server} do
      {:ok, app} =
        Apps.create_app(%{
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
