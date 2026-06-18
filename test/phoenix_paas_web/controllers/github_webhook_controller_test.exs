defmodule PhoenixPaasWeb.GithubWebhookControllerTest do
  use PhoenixPaasWeb.ConnCase, async: false

  alias PhoenixPaas.{Apps, Servers}

  setup do
    {:ok, server} =
      Servers.create_server(%{
        name: "lightsail-1",
        host_ip: "100.59.80.29",
        ssh_user: "ubuntu",
        region: "us-east-1"
      })

    {:ok, app} =
      Apps.create_app(%{
        name: "Trip Planner",
        slug: "trip-planner",
        github_repo: "puppe1990/trip-planner-ia-phx",
        host: "trip.gestaobem.com",
        server_id: server.id
      })

    payload = File.read!("test/support/fixtures/github_push.json")
    signature = sign(payload, app.webhook_secret)

    %{app: app, payload: payload, signature: signature}
  end

  test "returns 401 without signature", %{payload: payload} do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/webhooks/github", payload)

    assert response(conn, 401) == "invalid signature"
  end

  test "returns 401 with invalid signature", %{payload: payload} do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-hub-signature-256", "sha256=invalid")
      |> post(~p"/webhooks/github", payload)

    assert response(conn, 401) == "invalid signature"
  end

  test "queues deploy on valid push to main", %{payload: payload, signature: signature} do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-hub-signature-256", signature)
      |> post(~p"/webhooks/github", payload)

    assert response(conn, 202) == "queued"
    assert_enqueued(worker: PhoenixPaas.Workers.DeployWorker)
  end

  test "returns 404 for unknown repo", %{} do
    payload =
      ~s({"ref":"refs/heads/main","after":"abc123","repository":{"full_name":"unknown/repo"}})

    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-hub-signature-256", sign(payload, "secret"))
      |> post(~p"/webhooks/github", payload)

    assert response(conn, 404) == "unknown repo"
  end

  defp sign(body, secret) do
    "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower))
  end
end
