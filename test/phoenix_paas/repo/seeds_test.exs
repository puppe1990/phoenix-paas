defmodule PhoenixPaas.Repo.SeedsTest do
  use PhoenixPaas.DataCase, async: false

  alias PhoenixPaas.{Apps, Seeds, TenancyFixtures}

  test "seeds assign trip-planner to matheus tenant" do
    assert {:ok, %{user: user, scope: scope}} = Seeds.run()

    assert user.email == "matheus.puppe@gmail.com"
    assert scope.tenant.slug == "gestao-bem"

    apps = Apps.list_apps(scope)
    assert Enum.any?(apps, &(&1.slug == "trip-planner"))
    assert Enum.any?(apps, &(&1.slug == "rapid-tools"))
    assert Enum.any?(apps, &(&1.slug == "open-drive"))

    rapid_tools = Enum.find(apps, &(&1.slug == "rapid-tools"))
    assert rapid_tools.host == "tools.gestaobem.com"
    assert rapid_tools.port == 4001
    assert rapid_tools.systemd_unit == "rapid_tools"

    open_drive = Enum.find(apps, &(&1.slug == "open-drive"))
    assert open_drive.host == "drive.gestaobem.com"
    assert open_drive.port == 4002
    assert open_drive.systemd_unit == "open_drive"
  end

  test "seeds are idempotent" do
    assert {:ok, _} = Seeds.run()
    assert {:ok, _} = Seeds.run()

    assert {:ok, %{scope: scope}} = Seeds.run()

    slugs = Apps.list_apps(scope) |> Enum.map(& &1.slug) |> Enum.sort()
    assert slugs == ["open-drive", "rapid-tools", "trip-planner"]
  end

  test "matheus scope sees seeded apps but other user does not" do
    {:ok, %{scope: matheus_scope}} = Seeds.run()
    other_scope = TenancyFixtures.scope_fixture()

    matheus_apps = Apps.list_apps(matheus_scope)
    other_apps = Apps.list_apps(other_scope)

    assert Enum.any?(matheus_apps, &(&1.slug == "trip-planner"))
    assert Enum.any?(matheus_apps, &(&1.slug == "rapid-tools"))
    assert Enum.any?(matheus_apps, &(&1.slug == "open-drive"))
    refute Enum.any?(other_apps, &(&1.slug == "trip-planner"))
    refute Enum.any?(other_apps, &(&1.slug == "rapid-tools"))
    refute Enum.any?(other_apps, &(&1.slug == "open-drive"))
  end
end
