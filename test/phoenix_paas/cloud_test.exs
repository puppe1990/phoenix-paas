defmodule PhoenixPaas.CloudTest do
  use PhoenixPaas.DataCase

  import Mox

  alias PhoenixPaas.AWS.Lightsail.{Bundle, InstanceSpec}
  alias PhoenixPaas.AWS.LightsailMock
  alias PhoenixPaas.Cloud
  alias PhoenixPaas.HetznerMock
  alias PhoenixPaas.TenancyFixtures

  setup :verify_on_exit!

  setup do
    %{scope: TenancyFixtures.scope_fixture()}
  end

  test "sync_specs uses the Hetzner client for hetzner servers", %{scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{
        provider: "hetzner",
        region: "fsn1",
        aws_instance_name: "gestaobem-cx33",
        ssh_user: "ubuntu"
      })

    spec = %InstanceSpec{
      bundle_id: "cx33",
      bundle_name: "CX33",
      cpu_count: 4,
      ram_mb: 8192,
      disk_gb: 80,
      status: "running",
      blueprint_name: "Ubuntu 24.04",
      monthly_price_usd: Decimal.new("7.59")
    }

    expect(HetznerMock, :get_instance, fn "fsn1", "gestaobem-cx33" -> {:ok, spec} end)

    assert {:ok, updated} = Cloud.sync_specs(server)
    assert updated.bundle_id == "cx33"
    assert updated.cpu_count == 4
    assert updated.ram_mb == 8192
  end

  test "list_resize_options uses Hetzner bundles for hetzner servers", %{scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{
        provider: "hetzner",
        region: "fsn1",
        aws_instance_name: "gestaobem-cx33",
        bundle_id: "cx33"
      })

    bundles = [
      %Bundle{
        bundle_id: "cx33",
        bundle_name: "CX33",
        cpu_count: 4,
        ram_mb: 8192,
        disk_gb: 80,
        monthly_price_usd: Decimal.new("7.59")
      },
      %Bundle{
        bundle_id: "cx43",
        bundle_name: "CX43",
        cpu_count: 8,
        ram_mb: 16_384,
        disk_gb: 160,
        monthly_price_usd: Decimal.new("13.59")
      }
    ]

    expect(HetznerMock, :list_bundles, fn "fsn1" -> {:ok, bundles} end)

    assert options = Cloud.list_resize_options(server)
    assert Enum.map(options, & &1.bundle_id) == ["cx43"]
  end

  test "resize_bundle uses the Hetzner client for hetzner servers", %{scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{
        provider: "hetzner",
        region: "fsn1",
        aws_instance_name: "gestaobem-cx33",
        bundle_id: "cx33"
      })

    upgraded = %InstanceSpec{
      bundle_id: "cx43",
      bundle_name: "CX43",
      cpu_count: 8,
      ram_mb: 16_384,
      disk_gb: 160,
      status: "running",
      blueprint_name: "Ubuntu 24.04",
      monthly_price_usd: Decimal.new("13.59")
    }

    expect(HetznerMock, :change_bundle, fn "fsn1", "gestaobem-cx33", "cx43" -> :ok end)
    expect(HetznerMock, :get_instance, fn "fsn1", "gestaobem-cx33" -> {:ok, upgraded} end)

    assert {:ok, updated} = Cloud.resize_bundle(server, "cx43")
    assert updated.bundle_id == "cx43"
    assert updated.ram_mb == 16_384
  end

  test "sync_specs still uses Lightsail for lightsail servers", %{scope: scope} do
    server =
      TenancyFixtures.server_fixture(scope, %{
        provider: "lightsail",
        region: "us-east-1",
        aws_instance_name: "catalogo-lightsail"
      })

    spec = %InstanceSpec{
      bundle_id: "small_3_0",
      bundle_name: "Small",
      cpu_count: 2,
      ram_mb: 2048,
      disk_gb: 60,
      status: "running",
      blueprint_name: "Ubuntu",
      monthly_price_usd: Decimal.new("12.00")
    }

    expect(LightsailMock, :get_instance, fn "us-east-1", "catalogo-lightsail" -> {:ok, spec} end)

    assert {:ok, updated} = Cloud.sync_specs(server)
    assert updated.bundle_id == "small_3_0"
  end
end
