defmodule PhoenixPaas.ServersTest do
  use PhoenixPaas.DataCase

  alias PhoenixPaas.Servers

  describe "create_server/1" do
    test "persists a valid server" do
      attrs = %{
        name: "trip-planner",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      }

      assert {:ok, server} = Servers.create_server(attrs)
      assert server.name == "trip-planner"
      assert server.host_ip == "100.59.80.29"
      assert server.ssh_user == "ubuntu"
      assert server.region == "us-east-1"
    end

    test "rejects invalid IP" do
      attrs = %{
        name: "bad",
        host_ip: "not-an-ip",
        ssh_user: "ubuntu",
        region: "us-east-1"
      }

      assert {:error, changeset} = Servers.create_server(attrs)
      assert "is invalid" in errors_on(changeset).host_ip
    end
  end
end
