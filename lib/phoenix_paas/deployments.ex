defmodule PhoenixPaas.Deployments do
  @moduledoc """
  Deployment history and status transitions.
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Apps.App
  alias PhoenixPaas.Deployments.Deployment
  alias PhoenixPaas.Repo

  def create_deployment(%App{} = app, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:triggered_by, "manual")
      |> Map.put(:app_id, app.id)

    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  def enqueue(%App{} = app, attrs) do
    with {:ok, deployment} <- create_deployment(app, attrs),
         {:ok, job} <-
           %{deployment_id: deployment.id}
           |> PhoenixPaas.Workers.DeployWorker.new()
           |> Oban.insert() do
      {:ok, job}
    end
  end

  def get_deployment!(id), do: Repo.get!(Deployment, id) |> Repo.preload(:app)

  def for_app(%App{} = app) do
    Repo.all(
      from d in Deployment,
        where: d.app_id == ^app.id,
        order_by: [desc: d.inserted_at, desc: d.id]
    )
  end

  def mark_running(%Deployment{id: id}) do
    case Repo.get(Deployment, id) do
      %Deployment{status: :queued} = deployment ->
        deployment
        |> Deployment.changeset(%{status: :running, started_at: DateTime.utc_now(:second)})
        |> Repo.update()

      %Deployment{} ->
        {:error, :invalid_status}

      nil ->
        {:error, :invalid_status}
    end
  end

  def mark_success(%Deployment{id: id}, message) when is_binary(message) do
    case Repo.get(Deployment, id) do
      %Deployment{status: :running} = deployment ->
        deployment
        |> Deployment.changeset(%{
          status: :success,
          finished_at: DateTime.utc_now(:second),
          log: append_log(deployment.log, message)
        })
        |> Repo.update()

      %Deployment{} ->
        {:error, :invalid_status}

      nil ->
        {:error, :invalid_status}
    end
  end

  def mark_failed(%Deployment{id: id}, message) when is_binary(message) do
    case Repo.get(Deployment, id) do
      %Deployment{status: status} = deployment when status in [:queued, :running] ->
        deployment
        |> Deployment.changeset(%{
          status: :failed,
          finished_at: DateTime.utc_now(:second),
          log: append_log(deployment.log, message)
        })
        |> Repo.update()

      %Deployment{} ->
        {:error, :invalid_status}

      nil ->
        {:error, :invalid_status}
    end
  end

  defp append_log(existing, message) do
    [existing, message]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end
end
