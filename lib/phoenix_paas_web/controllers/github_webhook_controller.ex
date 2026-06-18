defmodule PhoenixPaasWeb.GithubWebhookController do
  use PhoenixPaasWeb, :controller

  alias PhoenixPaas.{Apps, Deployments, Github}

  def create(conn, _params) do
    raw_body = conn.private[:raw_body] || ""
    signature = get_req_header(conn, "x-hub-signature-256") |> List.first()

    with {:ok, payload} <- decode_payload(raw_body),
         repo when is_binary(repo) <- Github.repo_full_name(payload),
         %{} = app <- find_app_by_repo_and_signature(repo, raw_body, signature),
         {:ok, attrs} <- normalize_push_attrs(payload, app),
         true <- app.auto_deploy,
         {:ok, _job} <- Deployments.enqueue(app, attrs) do
      send_resp(conn, :accepted, "queued")
    else
      :not_found ->
        send_resp(conn, :not_found, "unknown repo")

      :ignore ->
        send_resp(conn, :ok, "ignored")

      false ->
        send_resp(conn, :ok, "auto deploy disabled")

      :error ->
        send_resp(conn, :unauthorized, "invalid signature")

      {:error, _} ->
        send_resp(conn, :bad_request, "invalid payload")
    end
  end

  defp find_app_by_repo_and_signature(repo, raw_body, signature) do
    apps = Apps.list_apps_by_repo(repo)

    cond do
      apps == [] ->
        :not_found

      signature in [nil, ""] ->
        :error

      true ->
        Enum.find_value(apps, :error, fn app ->
          case Github.verify_signature(raw_body, signature, app.webhook_secret) do
            :ok -> app
            :error -> nil
          end
        end)
    end
  end

  defp decode_payload(raw_body) when is_binary(raw_body) and raw_body != "" do
    case Jason.decode(raw_body) do
      {:ok, payload} -> {:ok, payload}
      _ -> {:error, :invalid_json}
    end
  end

  defp decode_payload(_), do: {:error, :empty_body}

  defp normalize_push_attrs(payload, app) do
    case Github.push_deploy_attrs(payload, app.branch) do
      {:ok, attrs} -> {:ok, attrs}
      :ignore -> :ignore
    end
  end
end
