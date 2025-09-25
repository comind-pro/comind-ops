#!/bin/bash
# PostgreSQL Service Implementation
# Concrete implementation of base service for PostgreSQL

set -euo pipefail

# Source the base service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "${BASE_DIR}/modules/base/service.sh"

# Service-specific configuration
SERVICE_NAME="${SERVICE_NAME:-postgresql}"
SERVICE_TYPE="${SERVICE_TYPE:-postgresql}"
SERVICE_VERSION="${SERVICE_VERSION:-15-alpine}"

# PostgreSQL specific variables
POSTGRES_DB="${POSTGRES_DB:-comind_ops_dev}"
POSTGRES_USER="${POSTGRES_USER:-comind_ops_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-comind_ops_password}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
DATA_DIR="${DATA_DIR:-./data/postgresql}"

# Docker configuration
CONTAINER_NAME="comind-ops-postgresql"
IMAGE_NAME="postgres:${SERVICE_VERSION}"
NETWORK_NAME="${NETWORK_NAME:-comind-ops-network}"

# Override abstract methods with PostgreSQL implementation
function start() {
    log "Starting PostgreSQL service..."
    
    # Create data directory if it doesn't exist
    mkdir -p "${DATA_DIR}"
    
    # Check if container already exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            warning "PostgreSQL container is already running"
            return 0
        else
            log "Starting existing PostgreSQL container..."
            docker start "${CONTAINER_NAME}"
        fi
    else
        log "Creating new PostgreSQL container..."
        docker run -d \
            --name "${CONTAINER_NAME}" \
            --network "${NETWORK_NAME}" \
            -p "${POSTGRES_PORT}:5432" \
            -e POSTGRES_DB="${POSTGRES_DB}" \
            -e POSTGRES_USER="${POSTGRES_USER}" \
            -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
            -v "${DATA_DIR}:/var/lib/postgresql/data" \
            "${IMAGE_NAME}"
    fi
    
    # Wait for PostgreSQL to be ready
    log "Waiting for PostgreSQL to be ready..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if docker exec "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; then
            success "PostgreSQL is ready!"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    error "PostgreSQL failed to start within timeout"
    return 1
}

function stop() {
    log "Stopping PostgreSQL service..."
    
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "${CONTAINER_NAME}"
        success "PostgreSQL stopped"
    else
        warning "PostgreSQL container is not running"
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
    log "Checking PostgreSQL health..."
    
    local status_result
    status_result=$(status)
    
    if [ "$status_result" = "Running" ]; then
        if docker exec "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; then
            success "PostgreSQL is healthy"
            return 0
        else
            error "PostgreSQL is running but not responding"
            return 1
        fi
    else
        error "PostgreSQL is not running (status: $status_result)"
        return 1
    fi
}

function recover() {
    log "Attempting to recover PostgreSQL service..."
    
    local status_result
    status_result=$(status)
    
    case "$status_result" in
        "Not created")
            log "Creating PostgreSQL container..."
            start
            ;;
        "Stopped")
            log "Starting stopped PostgreSQL container..."
            start
            ;;
        "Running")
            if ! healthcheck >/dev/null 2>&1; then
                log "PostgreSQL is running but unhealthy, restarting..."
                restart
            else
                success "PostgreSQL is already healthy"
            fi
            ;;
        *)
            error "Unknown status: $status_result"
            return 1
            ;;
    esac
}

function build() {
    log "Building PostgreSQL service..."
    
    # Pull the latest image
    docker pull "${IMAGE_NAME}"
    
    # Create necessary directories
    mkdir -p "${DATA_DIR}"
    
    success "PostgreSQL service built successfully"
}

function configure() {
    log "Configuring PostgreSQL service..."
    
    # Create data directory
    mkdir -p "${DATA_DIR}"
    
    # Set proper permissions
    chmod 755 "${DATA_DIR}"
    
    success "PostgreSQL service configured"
}

function validate() {
    log "Validating PostgreSQL configuration..."
    
    # Check if required variables are set
    local required_vars=("POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_PORT")
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
    
    success "PostgreSQL configuration is valid"
    return 0
}

# Override get_service_info to include PostgreSQL-specific info
function get_service_info() {
    cat << EOF
PostgreSQL Service Information:
  Name: ${SERVICE_NAME}
  Type: ${SERVICE_TYPE}
  Version: ${SERVICE_VERSION}
  Database: ${POSTGRES_DB}
  User: ${POSTGRES_USER}
  Port: ${POSTGRES_PORT}
  Data Directory: ${DATA_DIR}
  Container: ${CONTAINER_NAME}
  Status: $(status 2>/dev/null || echo "Unknown")
EOF
}

# Export PostgreSQL-specific functions
export -f start stop status healthcheck recover build configure validate get_service_info

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
