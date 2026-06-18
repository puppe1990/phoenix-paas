defmodule PhoenixPaas.Github do
  @moduledoc """
  GitHub webhook helpers.
  """

  @doc """
  Verifies `X-Hub-Signature-256` for a raw JSON payload.
  """
  def verify_signature(raw_body, signature, secret)
      when is_binary(raw_body) and is_binary(signature) and is_binary(secret) do
    expected =
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, raw_body) |> Base.encode16(case: :lower))

    if Plug.Crypto.secure_compare(expected, signature) do
      :ok
    else
      :error
    end
  end

  def verify_signature(_, _, _), do: :error

  @doc """
  Parses push event payload and returns deploy attrs when branch matches.
  """
  def push_deploy_attrs(payload, branch \\ "main") do
    with %{"ref" => "refs/heads/" <> ref, "after" => sha} <- payload,
         true <- ref == branch,
         false <- sha in [nil, String.duplicate("0", 40)] do
      {:ok, %{git_sha: sha, git_ref: ref, triggered_by: "webhook"}}
    else
      _ -> :ignore
    end
  end

  def repo_full_name(%{"repository" => %{"full_name" => full_name}}), do: full_name
  def repo_full_name(_), do: nil
end
