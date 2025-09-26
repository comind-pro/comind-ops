#!/bin/bash
# Common functions library for platform scripts

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Utility functions
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is not installed or not in PATH"
        return 1
    fi
}

check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Docker functions
docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

wait_for_service() {
    local service_name="$1"
    local max_retries="${2:-30}"
    local retry_interval="${3:-2}"
    
    log "Waiting for $service_name to be ready..."
    
    local retries=0
    while [ $retries -lt $max_retries ]; do
        if docker ps --filter "name=$service_name" --filter "status=running" --format "{{.Names}}" | grep -q "$service_name"; then
            success "$service_name is ready!"
            return 0
        fi
        
        sleep $retry_interval
        retries=$((retries + 1))
        log "Waiting for $service_name... ($retries/$max_retries)"
    done
    
    error "$service_name failed to start within $((max_retries * retry_interval)) seconds"
    return 1
}

# Kubernetes functions
wait_for_k8s_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-default}"
    local max_retries="${4:-30}"
    local retry_interval="${5:-2}"
    
    log "Waiting for $resource_type/$resource_name in namespace $namespace..."
    
    local retries=0
    while [ $retries -lt $max_retries ]; do
        if kubectl get "$resource_type" "$resource_name" -n "$namespace" &> /dev/null; then
            success "$resource_type/$resource_name is ready!"
            return 0
        fi
        
        sleep $retry_interval
        retries=$((retries + 1))
        log "Waiting for $resource_type/$resource_name... ($retries/$max_retries)"
    done
    
    error "$resource_type/$resource_name failed to be ready within $((max_retries * retry_interval)) seconds"
    return 1
}

# File operations
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        log "Backing up $file to $backup"
        cp "$file" "$backup"
        echo "$backup"
    fi
}

# Configuration functions
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        log "Loading environment from $env_file"
        set -a
        source "$env_file"
        set +a
    else
        warning "Environment file $env_file not found"
    fi
}

# Validation functions
validate_yaml() {
    local file="$1"
    if command -v yamllint &> /dev/null; then
        yamllint "$file"
    elif command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$file'))"
    else
        warning "No YAML validator available, skipping validation for $file"
    fi
}

validate_json() {
    local file="$1"
    if command -v jq &> /dev/null; then
        jq empty "$file"
    elif command -v python3 &> /dev/null; then
        python3 -c "import json; json.load(open('$file'))"
    else
        warning "No JSON validator available, skipping validation for $file"
    fi
}

# Network functions
check_port() {
    local port="$1"
    local host="${2:-localhost}"
    
    if command -v nc &> /dev/null; then
        nc -z "$host" "$port"
    elif command -v telnet &> /dev/null; then
        timeout 1 telnet "$host" "$port" &> /dev/null
    else
        warning "No network tools available to check port $port"
        return 1
    fi
}

wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"
    local max_retries="${3:-30}"
    local retry_interval="${4:-2}"
    
    log "Waiting for $host:$port to be available..."
    
    local retries=0
    while [ $retries -lt $max_retries ]; do
        if check_port "$port" "$host"; then
            success "$host:$port is available!"
            return 0
        fi
        
        sleep $retry_interval
        retries=$((retries + 1))
        log "Waiting for $host:$port... ($retries/$max_retries)"
    done
    
    error "$host:$port is not available after $((max_retries * retry_interval)) seconds"
    return 1
}

# Process functions
kill_process_on_port() {
    local port="$1"
    
    if command -v lsof &> /dev/null; then
        local pid=$(lsof -ti:$port)
        if [ -n "$pid" ]; then
            log "Killing process $pid on port $port"
            kill -9 "$pid"
        fi
    else
        warning "lsof not available, cannot kill process on port $port"
    fi
}

# Export functions for use in other scripts
export -f log success error warning info debug
export -f check_command check_dependencies
export -f docker_compose_cmd wait_for_service
export -f wait_for_k8s_resource
export -f ensure_directory backup_file
export -f load_env_file
export -f validate_yaml validate_json
export -f check_port wait_for_port kill_process_on_port
