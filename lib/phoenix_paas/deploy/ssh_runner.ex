defmodule PhoenixPaas.Deploy.SshRunner do
  @moduledoc """
  SSH-based deploy runner for Hetzner and Lightsail targets.

  Clones the GitHub repo, uploads source, builds the OTP release on the VM,
  runs migrations, and restarts systemd — mirroring `scripts/deploy/update.sh`.
  """
  @behaviour PhoenixPaas.Deploy.Runner

  alias PhoenixPaas.{Apps, Deployments}
  alias PhoenixPaas.Deploy.Ssh

  @impl true
  def deploy(deployment) do
    deployment = Deployments.get_deployment!(deployment.id)
    app = Apps.get_app!(deployment.app_id)
    server = app.server

    Ssh.run_deploy(deployment, app, server)
  end
end
