defmodule PhoenixPaas.Deploy.SshRunner do
  @moduledoc """
  SSH-based deploy runner for Lightsail targets.
  Full implementation deferred to integration tests.
  """
  @behaviour PhoenixPaas.Deploy.Runner

  alias PhoenixPaas.{Apps, Deployments}

  @impl true
  def deploy(deployment) do
    deployment = Deployments.get_deployment!(deployment.id)
    app = Apps.get_app!(deployment.app_id)
    _env = Apps.env_map(app)

    {:error, :ssh_runner_not_implemented}
  end
end
