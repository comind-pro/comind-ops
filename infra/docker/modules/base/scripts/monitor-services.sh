#!/bin/bash
# Service Monitor Script
# Monitors service health and provides status updates

set -euo pipefail

ENVIRONMENT="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
DOCKER_MANAGER="${PROJECT_ROOT}/infra/docker/services/docker-manager.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[MONITOR]${NC} $1"; }
success() { echo -e "${GREEN}[MONITOR]${NC} $1"; }
warning() { echo -e "${YELLOW}[MONITOR]${NC} $1"; }
error() { echo -e "${RED}[MONITOR]${NC} $1" >&2; }

# Check if docker-manager exists
if [ ! -f "$DOCKER_MANAGER" ]; then
    error "Docker manager not found: $DOCKER_MANAGER"
    exit 1
fi

log "Starting service monitoring for environment: $ENVIRONMENT"

# Monitor services
while true; do
    log "Checking service health..."
    
    # Get service status
    if bash "$DOCKER_MANAGER" status-all; then
        success "All services healthy"
    else
        warning "Some services may have issues"
    fi
    
    # Wait before next check
    sleep 30
done
