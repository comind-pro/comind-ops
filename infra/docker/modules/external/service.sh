#!/bin/bash
# External Service Implementation
# Generic implementation for external services
# Can be configured via registry for any Docker service

set -euo pipefail

# Source the base service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${BASE_DIR}/modules/base/service.sh"

# Service-specific configuration (can be overridden via environment)
SERVICE_NAME="${SERVICE_NAME:-external}"
SERVICE_TYPE="${SERVICE_TYPE:-external}"
SERVICE_VERSION="${SERVICE_VERSION:-latest}"

# External service variables (configurable via registry)
EXTERNAL_IMAGE="${EXTERNAL_IMAGE:-nginx:alpine}"
EXTERNAL_PORT="${EXTERNAL_PORT:-8080}"
EXTERNAL_ENV="${EXTERNAL_ENV:-}"
EXTERNAL_VOLUMES="${EXTERNAL_VOLUMES:-}"
EXTERNAL_COMMAND="${EXTERNAL_COMMAND:-}"
EXTERNAL_ARGS="${EXTERNAL_ARGS:-}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-http://localhost:${EXTERNAL_PORT}/health}"

# Docker configuration
CONTAINER_NAME="comind-ops-${SERVICE_NAME}"
IMAGE_NAME="${EXTERNAL_IMAGE}"
NETWORK_NAME="${NETWORK_NAME:-comind-ops-network}"

# Parse environment variables into Docker format
function parse_env() {
    if [ -n "${EXTERNAL_ENV:-}" ]; then
        echo "${EXTERNAL_ENV}" | tr ',' '\n' | while IFS='=' read -r key value; do
            echo "-e ${key}=${value}"
        done
    fi
}

# Parse volume mounts into Docker format
function parse_volumes() {
    if [ -n "${EXTERNAL_VOLUMES:-}" ]; then
        echo "${EXTERNAL_VOLUMES}" | tr ',' '\n' | while IFS=':' read -r host_path container_path; do
            echo "-v ${host_path}:${container_path}"
        done
    fi
}

# Override abstract methods with external service implementation
function start() {
    log "Starting external service: ${SERVICE_NAME}..."
    
    # Check if container already exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            warning "External service container is already running"
            return 0
        else
            log "Starting existing external service container..."
            docker start "${CONTAINER_NAME}"
        fi
    else
        log "Creating new external service container..."
        
        # Build docker run command
        local docker_cmd="docker run -d --name ${CONTAINER_NAME} --network ${NETWORK_NAME} -p ${EXTERNAL_PORT}:${EXTERNAL_PORT}"
        
        # Add environment variables
        if [ -n "${EXTERNAL_ENV:-}" ]; then
            docker_cmd="${docker_cmd} $(parse_env | tr '\n' ' ')"
        fi
        
        # Add volume mounts
        if [ -n "${EXTERNAL_VOLUMES:-}" ]; then
            docker_cmd="${docker_cmd} $(parse_volumes | tr '\n' ' ')"
        fi
        
        # Add image and command
        docker_cmd="${docker_cmd} ${IMAGE_NAME}"
        
        # Add custom command if specified
        if [ -n "${EXTERNAL_COMMAND:-}" ]; then
            docker_cmd="${docker_cmd} ${EXTERNAL_COMMAND}"
        fi
        
        # Add custom args if specified
        if [ -n "${EXTERNAL_ARGS:-}" ]; then
            docker_cmd="${docker_cmd} ${EXTERNAL_ARGS}"
        fi
        
        # Execute the command
        eval "${docker_cmd}"
    fi
    
    # Wait for service to be ready (if healthcheck URL is provided)
    if [ -n "${HEALTHCHECK_URL:-}" ]; then
        log "Waiting for external service to be ready..."
        local retries=30
        while [ $retries -gt 0 ]; do
            if curl -s "${HEALTHCHECK_URL}" >/dev/null 2>&1; then
                success "External service is ready!"
                return 0
            fi
            sleep 2
            retries=$((retries - 1))
        done
        
        warning "External service may not be ready (healthcheck timeout)"
    fi
    
    success "External service started"
    return 0
}

function stop() {
    log "Stopping external service: ${SERVICE_NAME}..."
    
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "${CONTAINER_NAME}"
        success "External service stopped"
    else
        warning "External service container is not running"
    fi
}

function status() {
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Running"
        return 0
    elif docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "Stopped"
        return 1
    else
        echo "Not created"
        return 2
    fi
}

function healthcheck() {
    log "Checking external service health: ${SERVICE_NAME}..."
    
    local status_result
    status_result=$(status)
    
    if [ "$status_result" = "Running" ]; then
        if [ -n "${HEALTHCHECK_URL:-}" ]; then
            if curl -s "${HEALTHCHECK_URL}" >/dev/null 2>&1; then
                success "External service is healthy"
                return 0
            else
                error "External service is running but not responding to healthcheck"
                return 1
            fi
        else
            # No healthcheck URL, just check if container is running
            success "External service is running (no healthcheck configured)"
            return 0
        fi
    else
        error "External service is not running (status: $status_result)"
        return 1
    fi
}

function recover() {
    log "Attempting to recover external service: ${SERVICE_NAME}..."
    
    local status_result
    status_result=$(status)
    
    case "$status_result" in
        "Not created")
            log "Creating external service container..."
            start
            ;;
        "Stopped")
            log "Starting stopped external service container..."
            start
            ;;
        "Running")
            if ! healthcheck >/dev/null 2>&1; then
                log "External service is running but unhealthy, restarting..."
                restart
            else
                success "External service is already healthy"
            fi
            ;;
        *)
            error "Unknown status: $status_result"
            return 1
            ;;
    esac
}

function build() {
    log "Building external service: ${SERVICE_NAME}..."
    
    # Pull the specified image
    docker pull "${IMAGE_NAME}"
    
    success "External service built successfully"
}

function configure() {
    log "Configuring external service: ${SERVICE_NAME}..."
    
    # Create necessary directories for volume mounts
    if [ -n "${EXTERNAL_VOLUMES:-}" ]; then
        echo "${EXTERNAL_VOLUMES}" | tr ',' '\n' | while IFS=':' read -r host_path container_path; do
            if [ -d "$(dirname "${host_path}")" ]; then
                mkdir -p "${host_path}"
                chmod 755 "${host_path}"
            fi
        done
    fi
    
    success "External service configured"
}

function validate() {
    log "Validating external service configuration: ${SERVICE_NAME}..."
    
    # Check if required variables are set
    local required_vars=("EXTERNAL_IMAGE" "EXTERNAL_PORT")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required variable $var is not set"
            return 1
        fi
    done
    
    # Validate port is numeric
    if ! [[ "${EXTERNAL_PORT}" =~ ^[0-9]+$ ]]; then
        error "EXTERNAL_PORT must be numeric: ${EXTERNAL_PORT}"
        return 1
    fi
    
    success "External service configuration is valid"
    return 0
}

# Override get_service_info to include external service-specific info
function get_service_info() {
    cat << EOF
External Service Information:
  Name: ${SERVICE_NAME}
  Type: ${SERVICE_TYPE}
  Version: ${SERVICE_VERSION}
  Image: ${EXTERNAL_IMAGE}
  Port: ${EXTERNAL_PORT}
  Container: ${CONTAINER_NAME}
  Healthcheck: ${HEALTHCHECK_URL:-"Not configured"}
  Status: $(status 2>/dev/null || echo "Unknown")
EOF
}

# Export external service-specific functions
export -f start stop status healthcheck recover build configure validate get_service_info

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
