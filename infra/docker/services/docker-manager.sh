#!/bin/bash
# Docker Service Manager
# Main orchestrator for managing Docker services based on registry configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
REGISTRY_FILE="${PROJECT_ROOT}/infra/docker/registry/services.conf"
MODULES_DIR="${PROJECT_ROOT}/infra/docker/modules"

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

# Check if registry file exists
if [ ! -f "${REGISTRY_FILE}" ]; then
    error "Registry file not found: ${REGISTRY_FILE}"
    exit 1
fi

# Parse configuration file (simple key-value format)
function parse_registry() {
    local service_name="$1"
    local key="$2"
    
    grep "^${service_name}\.${key}=" "${REGISTRY_FILE}" | cut -d'=' -f2-
}

# Get enabled services from registry
function get_enabled_services() {
    grep "\.enabled=true$" "${REGISTRY_FILE}" | cut -d'.' -f1
}

# Get service module type
function get_service_module() {
    local service_name="$1"
    parse_registry "$service_name" "module"
}

# Check if service is enabled
function is_service_enabled() {
    local service_name="$1"
    local enabled=$(parse_registry "$service_name" "enabled")
    [ "$enabled" = "true" ]
}

# Execute service command
function execute_service_command() {
    local service_name="$1"
    local command="$2"
    local module_type
    
    # Check if service is enabled
    if ! is_service_enabled "$service_name"; then
        warning "Service '$service_name' is not enabled in registry"
        return 1
    fi
    
    # Get module type
    module_type=$(get_service_module "$service_name")
    if [ -z "$module_type" ]; then
        error "No module type found for service: $service_name"
        return 1
    fi
    
    # Check if module exists
    local service_script="${MODULES_DIR}/${module_type}/service.sh"
    if [ ! -f "$service_script" ]; then
        error "Service module not found: $service_script"
        return 1
    fi
    
    # Execute the command
    log "Executing '$command' for service '$service_name' (module: $module_type)"
    SERVICE_NAME="$service_name" bash "$service_script" "$command"
}

# List all services
function list_services() {
    log "Available services:"
    echo ""
    
    # Get all service names from registry
    grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\." "${REGISTRY_FILE}" | cut -d'.' -f1 | sort -u | while read -r service_name; do
        if is_service_enabled "$service_name"; then
            local module_type=$(get_service_module "$service_name")
            echo "  ✅ $service_name ($module_type)"
        else
            echo "  ❌ $service_name (disabled)"
        fi
    done
}

# Start all enabled services
function start_all() {
    log "Starting all enabled services..."
    
    get_enabled_services | while read -r service_name; do
        if [ -n "$service_name" ]; then
            execute_service_command "$service_name" "start"
        fi
    done
}

# Stop all services
function stop_all() {
    log "Stopping all services..."
    
    get_enabled_services | while read -r service_name; do
        if [ -n "$service_name" ]; then
            execute_service_command "$service_name" "stop"
        fi
    done
}

# Status of all services
function status_all() {
    log "Service status:"
    echo ""
    
    get_enabled_services | while read -r service_name; do
        if [ -n "$service_name" ]; then
            local status_result
            status_result=$(execute_service_command "$service_name" "status" 2>/dev/null || echo "Error")
            echo "  $service_name: $status_result"
        fi
    done
}

# Health check all services
function healthcheck_all() {
    log "Health checking all services..."
    echo ""
    
    get_enabled_services | while read -r service_name; do
        if [ -n "$service_name" ]; then
            execute_service_command "$service_name" "healthcheck"
        fi
    done
}

# Show help
function show_help() {
    cat << EOF
Docker Service Manager

Usage: $0 <command> [service_name]

Commands:
  start [service]     Start service(s)
  stop [service]      Stop service(s)
  restart [service]   Restart service(s)
  status [service]    Show service status
  healthcheck [service] Check service health
  recover [service]   Recover service(s)
  build [service]     Build service(s)
  configure [service] Configure service(s)
  validate [service]  Validate service configuration
  list               List all services
  start-all          Start all enabled services
  stop-all           Stop all services
  status-all          Show status of all services
  healthcheck-all     Health check all services
  help               Show this help

Examples:
  $0 start postgresql
  $0 status-all
  $0 healthcheck minio
  $0 start-all

Services are configured in: ${REGISTRY_FILE}
EOF
}

# Main command dispatcher
function main() {
    local command="${1:-help}"
    local service_name="${2:-}"
    
    case "$command" in
        start|stop|restart|status|healthcheck|recover|build|configure|validate)
            if [ -n "$service_name" ]; then
                execute_service_command "$service_name" "$command"
            else
                error "Service name required for command: $command"
                show_help
                exit 1
            fi
            ;;
        list)
            list_services
            ;;
        start-all)
            start_all
            ;;
        stop-all)
            stop_all
            ;;
        status-all)
            status_all
            ;;
        healthcheck-all)
            healthcheck_all
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

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi