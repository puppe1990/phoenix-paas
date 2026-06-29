#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "$ROOT/scripts/deploy/deploy.local.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/scripts/deploy/deploy.local.env"
fi

DEPLOY_IP="${DEPLOY_IP:-}"
DEPLOY_SSH_KEY="${DEPLOY_SSH_KEY:-$HOME/.ssh/lightsail-default-key-us-east-1.pem}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
APPS_SSH_KEY="${SEED_SSH_KEY_PATH:-$DEPLOY_SSH_KEY}"

if [[ -z "$DEPLOY_IP" ]]; then
  echo "Set DEPLOY_IP in scripts/deploy/deploy.local.env" >&2
  exit 1
fi

if [[ ! -f "$APPS_SSH_KEY" ]]; then
  echo "SSH key not found: $APPS_SSH_KEY" >&2
  exit 1
fi

REMOTE_KEY="/tmp/phoenix_paas_apps_ssh_key.pem"

scp -i "$DEPLOY_SSH_KEY" -o StrictHostKeyChecking=accept-new \
  "$APPS_SSH_KEY" "${DEPLOY_USER}@${DEPLOY_IP}:${REMOTE_KEY}"

ssh -i "$DEPLOY_SSH_KEY" -o StrictHostKeyChecking=accept-new "${DEPLOY_USER}@${DEPLOY_IP}" \
  "sudo chmod 600 ${REMOTE_KEY} && cd /opt/phoenix_paas/current && sudo bash -c 'set -a; source /etc/phoenix_paas/env; set +a; bin/phoenix_paas rpc \"
key = File.read!(\\\"${REMOTE_KEY}\\\")
server = PhoenixPaas.Repo.get!(PhoenixPaas.Servers.Server, 1)
{:ok, updated} =
  server
  |> PhoenixPaas.Servers.Server.changeset(%{ssh_private_key: key})
  |> PhoenixPaas.Repo.update()
IO.puts(\\\"ssh_key_configured=\\\#{PhoenixPaas.Servers.ssh_key_configured?(updated)}\\\")
\"' && sudo rm -f ${REMOTE_KEY}"

echo "→ SSH key synced to PaaS server record"