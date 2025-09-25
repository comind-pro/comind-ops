#!/bin/bash
# Docker Services Integration Script
# Integrates the modular Docker service system with the main platform

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOCKER_MANAGER="${PROJECT_ROOT}/infra/docker/services/docker-manager.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DOCKER-SERVICES]${NC} $1"; }
success() { echo -e "${GREEN}[DOCKER-SERVICES]${NC} $1"; }
warning() { echo -e "${YELLOW}[DOCKER-SERVICES]${NC} $1"; }
error() { echo -e "${RED}[DOCKER-SERVICES]${NC} $1" >&2; }

# Check if docker-manager exists
if [ ! -f "$DOCKER_MANAGER" ]; then
    error "Docker manager not found: $DOCKER_MANAGER"
    exit 1
fi

# Function to start all services
function start_services() {
    log "Starting all Docker services..."
    bash "$DOCKER_MANAGER" start-all
}

# Function to stop all services
function stop_services() {
    log "Stopping all Docker services..."
    bash "$DOCKER_MANAGER" stop-all
}

# Function to check service status
function check_status() {
    log "Checking Docker service status..."
    bash "$DOCKER_MANAGER" status-all
}

# Function to health check services
function health_check() {
    log "Performing health check on Docker services..."
    bash "$DOCKER_MANAGER" healthcheck-all
}

# Function to show service information
function show_info() {
    log "Docker Service Information:"
    echo ""
    bash "$DOCKER_MANAGER" list
    echo ""
    bash "$DOCKER_MANAGER" status-all
}

# Main command dispatcher
function main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        status)
            check_status
            ;;
        healthcheck)
            health_check
            ;;
        info)
            show_info
            ;;
        help|--help|-h)
            cat << EOF
Docker Services Integration

Usage: $0 <command>

Commands:
  start       Start all Docker services
  stop        Stop all Docker services
  status      Check service status
  healthcheck Perform health check
  info        Show service information
  help        Show this help

This script integrates the modular Docker service system
with the main platform infrastructure.

Services are managed via: $DOCKER_MANAGER
EOF
            ;;
        *)
            error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
