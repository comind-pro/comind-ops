#!/bin/bash
set -euo pipefail

# Port-forward helper for ingress and internal services
# Usage:
#   scripts/port-forward.sh start [ENV]
#   scripts/port-forward.sh stop
#   scripts/port-forward.sh status

ENVIRONMENT=${2:-${ENV:-dev}}

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1" 1>&2; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command '$1' not found"; exit 1; fi
}

require kubectl

# Track background PIDs in a file to allow stopping later
STATE_DIR="/tmp/comind-ops"
PID_FILE="$STATE_DIR/port-forward.pids"
mkdir -p "$STATE_DIR"

kill_if_running() {
  local pattern="$1"
  pkill -f "$pattern" >/dev/null 2>&1 || true
}

start_ingress() {
  log "Starting ingress port-forward: 8080->ingress-nginx 80"
  kill_if_running "kubectl port-forward -n ingress-nginx"
  nohup kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
}

start_argocd() {
  log "Starting ArgoCD port-forward: 8082->argocd-server 80"
  kill_if_running "kubectl port-forward .* argocd-server -n argocd"
  nohup kubectl port-forward -n argocd svc/argocd-server 8082:80 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
}

start_monitoring() {
  log "Starting Grafana: localhost:3000"
  kill_if_running "kubectl port-forward .* svc/grafana -n monitoring"
  nohup kubectl port-forward -n monitoring svc/grafana 3000:3000 >/dev/null 2>&1 & echo $! >>"$PID_FILE"

  log "Starting Prometheus: localhost:9090"
  kill_if_running "kubectl port-forward .* svc/prometheus -n monitoring"
  nohup kubectl port-forward -n monitoring svc/prometheus 9090:9090 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
}

start_minio() {
  local ns="platform-${ENVIRONMENT}"
  log "Starting MinIO console: localhost:9001 (${ns})"
  kill_if_running "kubectl port-forward .* svc/minio-${ENVIRONMENT} -n ${ns}"
  # Try typical service names
  if kubectl get svc -n "$ns" | grep -q "minio"; then
    local svc
    svc=$(kubectl get svc -n "$ns" -o name | grep minio | head -1)
    nohup kubectl port-forward -n "$ns" "$svc" 9000:9000 9001:9001 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
  else
    warn "MinIO service not found in namespace ${ns}"
  fi
}

start_registry() {
  local ns="platform-${ENVIRONMENT}"
  log "Starting registry: localhost:5000 (${ns})"
  if kubectl get svc -n "$ns" | grep -q "registry"; then
    local svc
    svc=$(kubectl get svc -n "$ns" -o name | grep registry | head -1)
    kill_if_running "kubectl port-forward .* ${svc} -n ${ns}"
    nohup kubectl port-forward -n "$ns" "$svc" 5000:5000 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
  else
    warn "Registry service not found in namespace ${ns}"
  fi
}

start_elasticmq() {
  local ns="platform-${ENVIRONMENT}"
  log "Starting ElasticMQ: localhost:9324 (${ns})"
  if kubectl get svc -n "$ns" | grep -q "elasticmq"; then
    local svc
    svc=$(kubectl get svc -n "$ns" -o name | grep elasticmq | head -1)
    kill_if_running "kubectl port-forward .* ${svc} -n ${ns}"
    nohup kubectl port-forward -n "$ns" "$svc" 9324:9324 >/dev/null 2>&1 & echo $! >>"$PID_FILE"
  else
    warn "ElasticMQ service not found in namespace ${ns}"
  fi
}

start_all() {
  : >"$PID_FILE"
  start_ingress
  start_argocd
  start_monitoring
  start_minio
  start_registry
  start_elasticmq
  ok "Port-forwarding started. PIDs recorded at ${PID_FILE}"
}

stop_all() {
  if [ -f "$PID_FILE" ]; then
    while read -r pid; do
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
      fi
    done <"$PID_FILE"
    rm -f "$PID_FILE"
  fi
  # Also pkill any stray port-forward processes started manually
  pkill -f "kubectl port-forward" >/dev/null 2>&1 || true
  ok "Stopped all port-forward processes"
}

status() {
  echo "--- Port-forward status ---"
  if [ -f "$PID_FILE" ]; then
    while read -r pid; do
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "PID $pid: running"
      fi
    done <"$PID_FILE"
  else
    echo "No PID file at $PID_FILE"
  fi
  echo "Active kubectl port-forwards:"
  ps aux | grep "kubectl port-forward" | grep -v grep || true
}

case "${1:-}" in
  start)
    start_all ;;
  stop)
    stop_all ;;
  status)
    status ;;
  *)
    echo "Usage: $0 {start|stop|status} [ENV]"; exit 1 ;;
esac


