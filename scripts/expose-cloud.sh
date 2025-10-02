#!/bin/bash
set -euo pipefail

# Expose local ingress to the internet using Cloudflare Tunnel
# Supports two modes:
# 1) Token mode (recommended for CI/headless): CF_TUNNEL_TOKEN
#    cloudflared tunnel run --token $CF_TUNNEL_TOKEN
#    (Tunnel must have an ingress rule to http://localhost:8080)
# 2) Ad-hoc mode (interactive cert): CF_HOSTNAME + optional HOST_HEADER
#    cloudflared tunnel --hostname $CF_HOSTNAME --url http://localhost:8080 [--http-host-header <HOST_HEADER>]
#
# Usage:
#   scripts/expose-cloud.sh start [ENV]
#   scripts/expose-cloud.sh stop
#   scripts/expose-cloud.sh status
#
# Env vars:
#   CF_TUNNEL_TOKEN   - If set, runs a managed tunnel
#   CF_HOSTNAME       - Public hostname to bind (e.g., demo.example.com)
#   HOST_HEADER       - Host header to send to local ingress (default: monitoring.$ENV.127.0.0.1.nip.io)
#   ORIGIN_PORT       - Local ingress HTTP port (default: 8080)

ENVIRONMENT=${2:-${ENV:-dev}}
ORIGIN_PORT=${ORIGIN_PORT:-8080}
STATE_DIR="/tmp/comind-ops"
PID_FILE="$STATE_DIR/cloudflared.pid"
LOG_FILE="$STATE_DIR/cloudflared.log"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1" 1>&2; }

require() { command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found"; exit 1; }; }

mkdir -p "$STATE_DIR"

start_token_mode() {
  require cloudflared
  if [ -z "${CF_TUNNEL_TOKEN:-}" ]; then
    return 1
  fi
  log "Starting Cloudflare Tunnel (token mode)"
  nohup cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" >"$LOG_FILE" 2>&1 & echo $! >"$PID_FILE"
  ok "Tunnel started with token. Ensure tunnel routes to http://localhost:${ORIGIN_PORT} in Cloudflare config"
}

start_ad_hoc_mode() {
  require cloudflared
  if [ -z "${CF_HOSTNAME:-}" ]; then
    return 1
  fi
  local host_header=${HOST_HEADER:-"monitoring.${ENVIRONMENT}.127.0.0.1.nip.io"}
  log "Starting Cloudflare Tunnel (ad-hoc) for ${CF_HOSTNAME} -> http://localhost:${ORIGIN_PORT} (Host: ${host_header})"
  nohup cloudflared tunnel --no-autoupdate --hostname "$CF_HOSTNAME" \
    --url "http://localhost:${ORIGIN_PORT}" \
    --http-host-header "$host_header" >"$LOG_FILE" 2>&1 & echo $! >"$PID_FILE"
  ok "Tunnel started for ${CF_HOSTNAME}"
}

start() {
  if pgrep -f "cloudflared" >/dev/null 2>&1; then
    warn "cloudflared appears to be running already"
  fi
  : >"$LOG_FILE"
  if ! start_token_mode; then
    if ! start_ad_hoc_mode; then
      err "No CF_TUNNEL_TOKEN or CF_HOSTNAME provided. Set one of them and retry."
      echo "\nQuick start (ad-hoc):"
      echo "  brew install cloudflared  # macOS"
      echo "  cloudflared login         # authenticate to your Cloudflare account"
      echo "  CF_HOSTNAME=demo.example.com HOST_HEADER=monitoring.${ENVIRONMENT}.127.0.0.1.nip.io make expose-cloud-start"
      exit 1
    fi
  fi
}

stop() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE" || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      ok "Stopped cloudflared (PID $pid)"
    fi
    rm -f "$PID_FILE"
  fi
  # Extra safety: kill stray processes
  pkill -f "cloudflared tunnel" >/dev/null 2>&1 || true
}

status() {
  echo "--- Cloud exposure status ---"
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE" || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "cloudflared: running (PID $pid)"
    else
      echo "cloudflared: not running (stale PID file)"
    fi
  else
    echo "cloudflared: not running"
  fi
  if [ -s "$LOG_FILE" ]; then
    echo "--- Recent logs ---"
    tail -n 10 "$LOG_FILE" || true
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|status} [ENV]"; exit 1 ;;
esac


