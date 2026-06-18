defmodule PhoenixPaas.Deploy.Runner do
  @moduledoc """
  Behaviour for executing app deployments.
  """

  alias PhoenixPaas.Deployments.Deployment

  @type deploy_result :: {:ok, String.t()} | {:error, term()}

  @callback deploy(Deployment.t()) :: deploy_result()
end
