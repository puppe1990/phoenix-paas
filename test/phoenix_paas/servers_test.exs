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

    test "accepts a hetzner provider", %{scope: scope} do
      attrs = %{
        name: "gestaobem-cx33",
        host_ip: "203.0.113.10",
        ssh_user: "ubuntu",
        region: "fsn1",
        provider: "hetzner",
        aws_instance_name: "gestaobem-cx33"
      }

      assert {:ok, server} = Servers.create_server(scope, attrs)
      assert server.provider == "hetzner"
      assert server.region == "fsn1"
    end

    test "formats hetzner prices in euro", %{scope: scope} do
      attrs = %{
        name: "gestaobem-cx33-price",
        host_ip: "203.0.113.11",
        ssh_user: "ubuntu",
        region: "fsn1",
        provider: "hetzner",
        monthly_price_usd: Decimal.new("7.59")
      }

      assert {:ok, server} = Servers.create_server(scope, attrs)
      assert Servers.Server.format_price(server) == "€7.59/mo"
    end

    test "rejects unknown provider", %{scope: scope} do
      attrs = %{
        name: "bad-provider",
        host_ip: "10.0.0.1",
        ssh_user: "ubuntu",
        region: "fsn1",
        provider: "digitalocean"
      }

      assert {:error, changeset} = Servers.create_server(scope, attrs)
      assert "is invalid" in errors_on(changeset).provider
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

  describe "update_host_ip/2" do
    test "updates the stored IPv4 address", %{scope: scope} do
      server = TenancyFixtures.server_fixture(scope, %{host_ip: "52.0.157.89"})

      assert {:ok, updated} = Servers.update_host_ip(server, "52.73.89.19")
      assert updated.host_ip == "52.73.89.19"
    end

    test "rejects an invalid IP", %{scope: scope} do
      server = TenancyFixtures.server_fixture(scope, %{host_ip: "10.0.0.1"})
      assert {:error, changeset} = Servers.update_host_ip(server, "not-an-ip")
      assert "is invalid" in errors_on(changeset).host_ip
    end
  end
end
