#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

DEPLOY_IP="${CATALOGO_SERVER_IP:-${DEPLOY_IP:-}}"
DEPLOY_SSH_KEY="${DEPLOY_SSH_KEY:-$HOME/.ssh/lightsail-default-key-us-east-1.pem}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"

log() {
  printf '→ %s\n' "$*" >&2
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ssh_cmd() {
  ssh -i "$DEPLOY_SSH_KEY" \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    "${DEPLOY_USER}@${DEPLOY_IP}" "$@"
}

main() {
  require_command ssh

  [[ -n "$DEPLOY_IP" ]] || die "Set CATALOGO_SERVER_IP or DEPLOY_IP to the catalog Lightsail public IP"
  [[ -f "$DEPLOY_SSH_KEY" ]] || die "SSH key not found: $DEPLOY_SSH_KEY"
  chmod 600 "$DEPLOY_SSH_KEY"

  log "Bootstrapping catalogo server on $DEPLOY_USER@$DEPLOY_IP"

  ssh_cmd "bash -s" <<'REMOTE'
set -euo pipefail

log() { printf '→ %s\n' "$*" >&2; }

if ! swapon --show | grep -q /swapfile; then
  log "Creating 2GB swap"
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

log "Installing deploy runner dependencies"
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git openssh-client tar curl ca-certificates build-essential

if ! command -v caddy >/dev/null 2>&1; then
  log "Installing Caddy"
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y caddy
fi

sudo mkdir -p /opt/catalog_platform/releases /etc/catalog_platform /etc/caddy
sudo systemctl enable caddy

log "Bootstrap complete — deploy catalogo from paas.gestaobem.com"
REMOTE

  log "Bootstrap finished for $DEPLOY_IP"
}

main "$@"