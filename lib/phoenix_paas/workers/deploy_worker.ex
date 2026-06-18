defmodule PhoenixPaas.Workers.DeployWorker do
  @moduledoc false
  use Oban.Worker, queue: :deploys, max_attempts: 3

  alias PhoenixPaas.Deployments

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) when is_map(args) do
    deployment_id = Map.get(args, "deployment_id") || Map.get(args, :deployment_id)
    deployment = Deployments.get_deployment!(deployment_id)

    with {:ok, running} <- Deployments.mark_running(deployment),
         running = Deployments.get_deployment!(running.id),
         {:ok, message} <- runner().deploy(running),
         {:ok, _success} <- Deployments.mark_success(running, message) do
      :ok
    else
      {:error, :invalid_status} = error ->
        error

      {:error, reason} ->
        deployment = Deployments.get_deployment!(deployment_id)
        _ = Deployments.mark_failed(deployment, format_error(reason))
        {:error, reason}
    end
  end

  defp runner do
    Application.get_env(:phoenix_paas, :deploy_runner, PhoenixPaas.Deploy.FakeRunner)
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
