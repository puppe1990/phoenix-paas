defmodule PhoenixPaas.Workers.AutoDeployHealthWorker do
  @moduledoc false
  # Do not set `unique:` — Oban Lite unique SQL is rejected by Turso/libSQL.
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  require Logger

  alias PhoenixPaas.Apps
  alias PhoenixPaas.Deploy.Target

  @impl Oban.Worker
  def perform(_job) do
    webhooks = Apps.sync_all_github_webhooks()
    ips = Target.reconcile_server_ips()

    Logger.info("auto_deploy_health webhooks=#{inspect(webhooks)} server_ips=#{inspect(ips)}")
    :ok
  end
end
