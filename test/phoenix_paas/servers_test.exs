defmodule PhoenixPaas.ServersTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.Servers
  alias PhoenixPaas.TenancyFixtures

  setup do
    %{scope: TenancyFixtures.scope_fixture()}
  end

  describe "create_server/2" do
    test "persists a valid server", %{scope: scope} do
      attrs = %{
        name: "trip-planner",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      }

      assert {:ok, server} = Servers.create_server(scope, attrs)
      assert server.name == "trip-planner"
      assert server.tenant_id == scope.tenant.id
    end

    test "encrypts SSH private key", %{scope: scope} do
      attrs = %{
        name: "trip-planner",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1",
        ssh_private_key: "-----BEGIN TEST KEY-----\nsecret\n-----END TEST KEY-----"
      }

      assert {:ok, server} = Servers.create_server(scope, attrs)
      server = Servers.get_server!(scope, server.id)
      assert Servers.ssh_key_configured?(server)
    end

    test "rejects invalid IP", %{scope: scope} do
      attrs = %{
        name: "bad",
        host_ip: "not-an-ip",
        ssh_user: "ubuntu",
        region: "us-east-1"
      }

      assert {:error, changeset} = Servers.create_server(scope, attrs)
      assert "is invalid" in errors_on(changeset).host_ip
    end
  end
end
