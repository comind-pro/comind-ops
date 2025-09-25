#!/bin/bash
# MinIO Service Implementation
# Concrete implementation of base service for MinIO

set -euo pipefail

# Source the base service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${BASE_DIR}/modules/base/service.sh"

# Service-specific configuration
SERVICE_NAME="${SERVICE_NAME:-minio}"
SERVICE_TYPE="${SERVICE_TYPE:-minio}"
SERVICE_VERSION="${SERVICE_VERSION:-latest}"

# MinIO specific variables
MINIO_ROOT_USER="${MINIO_ROOT_USER:-comind_ops_minio_admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-comind_ops_minio_password}"
MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
MINIO_API_PORT="${MINIO_API_PORT:-9000}"
DATA_DIR="${DATA_DIR:-./data/minio}"

# Docker configuration
CONTAINER_NAME="comind-ops-minio"
IMAGE_NAME="minio/minio:${SERVICE_VERSION}"
NETWORK_NAME="${NETWORK_NAME:-comind-ops-network}"

# Override abstract methods with MinIO implementation
function start() {
    log "Starting MinIO service..."
    
    # Create data directory if it doesn't exist
    mkdir -p "${DATA_DIR}"
    
    # Check if container already exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            warning "MinIO container is already running"
            return 0
        else
            log "Starting existing MinIO container..."
            docker start "${CONTAINER_NAME}"
        fi
    else
        log "Creating new MinIO container..."
        docker run -d \
            --name "${CONTAINER_NAME}" \
            --network "${NETWORK_NAME}" \
            -p "${MINIO_API_PORT}:9000" \
            -p "${MINIO_CONSOLE_PORT}:9001" \
            -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
            -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
            -v "${DATA_DIR}:/data" \
            "${IMAGE_NAME}" \
            server /data --console-address ":9001"
    fi
    
    # Wait for MinIO to be ready
    log "Waiting for MinIO to be ready..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -s "http://localhost:${MINIO_API_PORT}/minio/health/live" >/dev/null 2>&1; then
            success "MinIO is ready!"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    error "MinIO failed to start within timeout"
    return 1
}

function stop() {
    log "Stopping MinIO service..."
    
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "${CONTAINER_NAME}"
        success "MinIO stopped"
    else
        warning "MinIO container is not running"
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
    log "Checking MinIO health..."
    
    local status_result
    status_result=$(status)
    
    if [ "$status_result" = "Running" ]; then
        if curl -s "http://localhost:${MINIO_API_PORT}/minio/health/live" >/dev/null 2>&1; then
            success "MinIO is healthy"
            return 0
        else
            error "MinIO is running but not responding"
            return 1
        fi
    else
        error "MinIO is not running (status: $status_result)"
        return 1
    fi
}

function recover() {
    log "Attempting to recover MinIO service..."
    
    local status_result
    status_result=$(status)
    
    case "$status_result" in
        "Not created")
            log "Creating MinIO container..."
            start
            ;;
        "Stopped")
            log "Starting stopped MinIO container..."
            start
            ;;
        "Running")
            if ! healthcheck >/dev/null 2>&1; then
                log "MinIO is running but unhealthy, restarting..."
                restart
            else
                success "MinIO is already healthy"
            fi
            ;;
        *)
            error "Unknown status: $status_result"
            return 1
            ;;
    esac
}

function build() {
    log "Building MinIO service..."
    
    # Pull the latest image
    docker pull "${IMAGE_NAME}"
    
    # Create necessary directories
    mkdir -p "${DATA_DIR}"
    
    success "MinIO service built successfully"
}

function configure() {
    log "Configuring MinIO service..."
    
    # Create data directory
    mkdir -p "${DATA_DIR}"
    
    # Set proper permissions
    chmod 755 "${DATA_DIR}"
    
    success "MinIO service configured"
}

function validate() {
    log "Validating MinIO configuration..."
    
    # Check if required variables are set
    local required_vars=("MINIO_ROOT_USER" "MINIO_ROOT_PASSWORD" "MINIO_API_PORT" "MINIO_CONSOLE_PORT")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error "Required variable $var is not set"
            return 1
        fi
    done
    
    # Check if data directory is writable
    if [ ! -w "$(dirname "${DATA_DIR}")" ]; then
        error "Data directory parent is not writable: $(dirname "${DATA_DIR}")"
        return 1
    fi
    
    success "MinIO configuration is valid"
    return 0
}

# Override get_service_info to include MinIO-specific info
function get_service_info() {
    cat << EOF
MinIO Service Information:
  Name: ${SERVICE_NAME}
  Type: ${SERVICE_TYPE}
  Version: ${SERVICE_VERSION}
  API Port: ${MINIO_API_PORT}
  Console Port: ${MINIO_CONSOLE_PORT}
  Root User: ${MINIO_ROOT_USER}
  Data Directory: ${DATA_DIR}
  Container: ${CONTAINER_NAME}
  Status: $(status 2>/dev/null || echo "Unknown")
EOF
}

# Export MinIO-specific functions
export -f start stop status healthcheck recover build configure validate get_service_info

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
