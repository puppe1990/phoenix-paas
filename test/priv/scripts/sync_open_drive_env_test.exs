defmodule Priv.Scripts.SyncOpenDriveEnvTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../../priv/scripts/sync_open_drive_env.exs", __DIR__)

  test "sync script maps OpenDrive-specific Turso env vars, not the panel database" do
    source = File.read!(@script)

    assert source =~ "OPEN_DRIVE_TURSO_DATABASE_URL"
    assert source =~ "OPEN_DRIVE_TURSO_AUTH_TOKEN"
    refute source =~ "System.get_env(\"TURSO_DATABASE_URL\")"
    refute source =~ "System.get_env(\"TURSO_AUTH_TOKEN\")"
  end
end