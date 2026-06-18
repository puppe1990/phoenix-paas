#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

START_PORT="${START_PORT:-4000}"

# ── Install dependencies if needed ──────────────────────────────────────────
if [ ! -d "deps" ] || [ ! -d "_build" ]; then
  echo "==> Installing dependencies..."
  mix deps.get
  mix setup
fi

# ── Find next available port ────────────────────────────────────────────────
find_port() {
  local port=$START_PORT
  while lsof -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; do
    port=$((port + 1))
  done
  echo "$port"
}

PORT=$(find_port)

echo "==> Starting Phoenix on port $PORT..."
PORT="$PORT" mix phx.server
