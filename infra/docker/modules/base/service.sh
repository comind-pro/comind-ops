#!/bin/bash
# Abstract Base Service Class
# Provides common interface for all Docker services
# Similar to OOP abstract class pattern

set -euo pipefail

# Service metadata
SERVICE_NAME="${SERVICE_NAME:-unknown}"
SERVICE_VERSION="${SERVICE_VERSION:-1.0.0}"
SERVICE_TYPE="${SERVICE_TYPE:-base}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Abstract methods - must be implemented by concrete services
function start() { 
    error "Abstract method 'start' not implemented in ${SERVICE_NAME}"
    return 1
}

function stop() { 
    error "Abstract method 'stop' not implemented in ${SERVICE_NAME}"
    return 1
}

function restart() { 
    log "Restarting ${SERVICE_NAME}..."
    stop && start
}

function status() { 
    error "Abstract method 'status' not implemented in ${SERVICE_NAME}"
    return 1
}

function healthcheck() { 
    error "Abstract method 'healthcheck' not implemented in ${SERVICE_NAME}"
    return 1
}

function recover() { 
    error "Abstract method 'recover' not implemented in ${SERVICE_NAME}"
    return 1
}

function build() { 
    error "Abstract method 'build' not implemented in ${SERVICE_NAME}"
    return 1
}

function configure() { 
    error "Abstract method 'configure' not implemented in ${SERVICE_NAME}"
    return 1
}

function validate() { 
    error "Abstract method 'validate' not implemented in ${SERVICE_NAME}"
    return 1
}

# Common utility methods
function get_service_info() {
    cat << EOF
Service Information:
  Name: ${SERVICE_NAME}
  Type: ${SERVICE_TYPE}
  Version: ${SERVICE_VERSION}
  Status: $(status 2>/dev/null || echo "Unknown")
EOF
}

function show_help() {
    cat << EOF
${SERVICE_NAME} Service Management

Usage: $0 <command>

Commands:
  start       Start the service
  stop        Stop the service
  restart     Restart the service
  status      Show service status
  healthcheck Check service health
  recover     Recover from failures
  build       Build service components
  configure   Configure service
  validate    Validate configuration
  info        Show service information
  help        Show this help

Examples:
  $0 start
  $0 status
  $0 healthcheck
EOF
}

# Main command dispatcher
function main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        healthcheck)
            healthcheck
            ;;
        recover)
            recover
            ;;
        build)
            build
            ;;
        configure)
            configure
            ;;
        validate)
            validate
            ;;
        info)
            get_service_info
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Export functions for inheritance
export -f start stop restart status healthcheck recover build configure validate
export -f get_service_info show_help main
export -f log success warning error

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
