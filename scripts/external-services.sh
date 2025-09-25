#!/bin/bash
set -euo pipefail

# External Services Management Script for Comind-Ops Platform
# Manages PostgreSQL and MinIO Docker containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/infra/docker"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[EXTERNAL-SERVICES]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Manage external services (PostgreSQL, MinIO) for Comind-Ops Platform

Commands:
    start           Start all external services
    stop            Stop all external services
    restart         Restart all external services
    status          Show status of all services
    logs            Show logs from all services
    backup          Run backup for all services
    restore         Restore from backup
    clean           Clean up all services and data
    setup           Initial setup of external services
    heal            Auto-heal service configuration issues
    help            Show this help message

Options:
    --env ENV       Environment (dev, stage, prod) - default: dev
    --service SVC   Target specific service (postgres, minio, all) - default: all
    --follow        Follow logs (for logs command)
    --backup-date   Backup date for restore (format: YYYYMMDD_HHMMSS)

Examples:
    $0 start                    # Start all services
    $0 status                   # Check service status
    $0 logs --follow            # Follow all service logs
    $0 backup --service postgres # Backup PostgreSQL only
    $0 restore --backup-date 20240101_120000
EOF
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is required but not installed"
        exit 1
    fi
    
    success "Dependencies check passed"
}

ensure_env_file() {
    local env_file="$DOCKER_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log "Creating .env file from template..."
        cp "$DOCKER_DIR/env.template" "$env_file"
        warning "Please customize the values in $env_file before starting services"
        
        # Set environment-specific defaults
        if [[ "$ENV" != "dev" ]]; then
            log "Updating environment to $ENV in .env file..."
            sed -i.bak "s/ENV=dev/ENV=$ENV/" "$env_file"
            rm -f "$env_file.bak"
        fi
    fi
}

docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

start_services() {
    log "Starting external services..."
    
    cd "$DOCKER_DIR"
    ensure_env_file
    
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    case "$SERVICE" in
        postgres)
            $compose_cmd up -d postgres
            ;;
        minio)
            $compose_cmd up -d minio minio-init
            ;;
        all|*)
            $compose_cmd up -d postgres minio minio-init
            ;;
    esac
    
    success "Services started successfully"
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 10
    show_status
}

stop_services() {
    log "Stopping external services..."
    
    cd "$DOCKER_DIR"
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    case "$SERVICE" in
        postgres)
            $compose_cmd stop postgres
            ;;
        minio)
            $compose_cmd stop minio minio-init
            ;;
        all|*)
            $compose_cmd down
            ;;
    esac
    
    success "Services stopped successfully"
}

restart_services() {
    log "Restarting external services..."
    stop_services
    sleep 5
    start_services
}

show_status() {
    log "External services status:"
    
    cd "$DOCKER_DIR"
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    $compose_cmd ps
    
    echo
    log "Service health checks:"
    
    # Check PostgreSQL
    if docker exec comind-ops-postgres pg_isready -U comind_ops_user -d comind_ops 2>/dev/null; then
        success "PostgreSQL: Healthy"
    else
        error "PostgreSQL: Unhealthy"
    fi
    
    # Check MinIO
    if docker exec comind-ops-minio curl -f http://localhost:9000/minio/health/live 2>/dev/null; then
        success "MinIO: Healthy"
    else
        error "MinIO: Unhealthy"
    fi
}

show_logs() {
    log "Showing service logs..."
    
    cd "$DOCKER_DIR"
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    local follow_flag=""
    [[ "$FOLLOW_LOGS" == "true" ]] && follow_flag="-f"
    
    case "$SERVICE" in
        postgres)
            $compose_cmd logs $follow_flag postgres
            ;;
        minio)
            $compose_cmd logs $follow_flag minio
            ;;
        all|*)
            $compose_cmd logs $follow_flag
            ;;
    esac
}

run_backup() {
    log "Running backup for $SERVICE..."
    
    cd "$DOCKER_DIR"
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    case "$SERVICE" in
        postgres)
            log "Running PostgreSQL backup..."
            $compose_cmd run --rm postgres-backup
            ;;
        minio)
            log "Running MinIO backup..."
            $compose_cmd run --rm minio-backup
            ;;
        all|*)
            log "Running all backups..."
            $compose_cmd run --rm postgres-backup
            $compose_cmd run --rm minio-backup
            ;;
    esac
    
    success "Backup completed successfully"
}

restore_backup() {
    if [[ -z "$BACKUP_DATE" ]]; then
        error "Backup date is required for restore operation"
        error "Use --backup-date YYYYMMDD_HHMMSS"
        exit 1
    fi
    
    log "Restoring from backup dated: $BACKUP_DATE"
    warning "This operation will overwrite existing data!"
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Restore cancelled"
        exit 0
    fi
    
    # Implementation would depend on specific restore requirements
    log "Restore functionality not yet implemented"
    log "Manual restore instructions:"
    log "1. Download backup from MinIO backups bucket"
    log "2. Extract and restore data manually"
    log "3. Restart services"
}

clean_services() {
    warning "This will remove all containers and data!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Clean cancelled"
        exit 0
    fi
    
    log "Cleaning up external services..."
    
    cd "$DOCKER_DIR"
    local compose_cmd
    compose_cmd=$(docker_compose_cmd)
    
    $compose_cmd down -v --remove-orphans
    
    # Remove named volumes
    docker volume rm comind-ops-postgres-data comind-ops-minio-data comind-ops-minio-config 2>/dev/null || true
    
    # Remove network
    docker network rm comind-ops-network 2>/dev/null || true
    
    success "Services and data cleaned up successfully"
}

setup_services() {
    log "Setting up external services..."
    
    check_dependencies
    ensure_env_file
    
    # Create necessary directories
    mkdir -p "$DOCKER_DIR"/{postgres/{init,config},scripts}
    
    log "Starting initial setup..."
    start_services
    
    log "Waiting for services to initialize..."
    sleep 30
    
    # Verify setup
    show_status
    
    success "External services setup completed!"
    log "Access URLs:"
    log "- PostgreSQL: localhost:5432"
    log "- MinIO API: http://localhost:9000"
    log "- MinIO Console: http://localhost:9001"
}

# Auto-heal services function - defined before main execution
heal_services() {
    log "🔧 Auto-healing external services..."
    local healing_performed=false
    
    # Ensure variables are set
    check_config || return 1
    
    # Check for PostgreSQL config errors and auto-fix
    local pg_logs=$(docker compose -f "$DOCKER_COMPOSE_FILE" logs postgres 2>&1 || echo "")
    if echo "$pg_logs" | grep -q "unrecognized configuration parameter"; then
        warning "PostgreSQL configuration error detected - auto-fixing..."
        
        # Auto-fix common config issues
        if echo "$pg_logs" | grep -q "log_collector"; then
            local postgres_config="$PROJECT_ROOT/infra/docker/postgres/config/postgresql.conf"
            if [ -f "$postgres_config" ]; then
                sed -i.bak '/log_collector/d' "$postgres_config" 2>/dev/null || true
                healing_performed=true
                log "Fixed log_collector parameter in PostgreSQL config"
            fi
        fi
        
        # Restart if healing was performed
        if [ "$healing_performed" = true ]; then
            log "Restarting PostgreSQL with corrected configuration..."
            docker compose -f "$DOCKER_COMPOSE_FILE" restart postgres
            sleep 5
            success "PostgreSQL auto-healed and restarted successfully."
        fi
    fi
    
    # Check for container restart loops and fix
    local pg_restarts=$(docker inspect comind-ops-postgres --format '{{.RestartCount}}' 2>/dev/null || echo "0")
    if [ "$pg_restarts" -gt 3 ]; then
        warning "PostgreSQL has restarted $pg_restarts times - recreating container..."
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate postgres
        healing_performed=true
    fi
    
    # Auto-fix MinIO permission issues
    if docker ps --filter name=comind-ops-minio --format "{{.Names}}" | grep -q comind-ops-minio; then
        if ! docker exec comind-ops-minio mc ready local 2>/dev/null; then
            log "MinIO readiness check failed - ensuring bucket permissions..."
            docker compose -f "$DOCKER_COMPOSE_FILE" restart minio-init 2>/dev/null || true
            healing_performed=true
        fi
    fi
    
    if [ "$healing_performed" = true ]; then
        success "🔧 External services auto-healing completed successfully."
        log "Waiting for services to stabilize..."
        sleep 10
    else
        success "✅ External services are healthy - no healing needed."
    fi
    
    return 0
}

# Parse command line arguments
COMMAND="${1:-help}"
shift || true

ENV="dev"
SERVICE="all"
FOLLOW_LOGS=false
BACKUP_DATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            ENV="$2"
            shift 2
            ;;
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --follow)
            FOLLOW_LOGS=true
            shift
            ;;
        --backup-date)
            BACKUP_DATE="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    start)
        check_dependencies
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        check_dependencies
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    backup)
        run_backup
        ;;
    restore)
        restore_backup
        ;;
    clean)
        clean_services
        ;;
    setup)
        setup_services
        ;;
    heal)
        heal_services
        ;;
    help)
        print_usage
        ;;
    *)
        error "Unknown command: $COMMAND"
        print_usage
        exit 1
        ;;
esac

# Auto-fix PostgreSQL configuration if needed
fix_postgres_config() {
    info "Checking PostgreSQL configuration..."
    
    if grep -q "log_collector = on" infra/docker/postgres/config/postgresql.conf 2>/dev/null; then
        info "Fixing PostgreSQL configuration parameter..."
        sed -i.bak 's/log_collector = on/logging_collector = on/' infra/docker/postgres/config/postgresql.conf
        success "PostgreSQL configuration fixed"
    fi
}

# Enhanced PostgreSQL setup with auto-healing
setup_postgres() {
    info "Setting up PostgreSQL with auto-healing..."
    
    # Fix configuration if needed
    if [ -f "infra/docker/postgres/config/postgresql.conf" ]; then
        if grep -q "log_collector = on" infra/docker/postgres/config/postgresql.conf; then
            info "Fixing PostgreSQL configuration..."
            sed -i.bak 's/log_collector = on/logging_collector = on/' infra/docker/postgres/config/postgresql.conf
            success "PostgreSQL configuration fixed"
            
            # Restart PostgreSQL to apply config fix
            info "Restarting PostgreSQL with fixed configuration..."
            docker-compose -f infra/docker/docker-compose.yml restart postgres
            
            # Wait for PostgreSQL to be healthy
            info "Waiting for PostgreSQL to be healthy..."
            local retries=30
            while [ $retries -gt 0 ]; do
                if docker-compose -f infra/docker/docker-compose.yml exec postgres pg_isready -U postgres > /dev/null 2>&1; then
                    success "PostgreSQL is healthy!"
                    return 0
                fi
                sleep 2
                retries=$((retries-1))
                info "Waiting for PostgreSQL... ($retries retries left)"
            done
            
            warning "PostgreSQL took longer than expected, but continuing..."
        fi
    fi
}

# Heal command - fix common issues
heal() {
    info "🔧 Healing external services..."
    
    # Fix PostgreSQL configuration and restart
    setup_postgres
    
    # Restart all services
    info "Restarting all services..."
    docker-compose -f infra/docker/docker-compose.yml restart
    
    # Wait for services to be ready
    info "Waiting for services to be ready..."
    sleep 10
    
    success "Service healing completed!"
}

# Add heal to the case statement
case "${1:-}" in
    heal)
        heal
        ;;
esac

# Auto-heal services function
heal_services() {
    log "🔧 Auto-healing external services..."
    local healing_performed=false
    
    # Check for PostgreSQL config errors and auto-fix
    local pg_logs=$(docker compose -f "$DOCKER_COMPOSE_FILE" logs postgres 2>&1)
    if echo "$pg_logs" | grep -q "unrecognized configuration parameter"; then
        warning "PostgreSQL configuration error detected - auto-fixing..."
        
        # Auto-fix common config issues
        if echo "$pg_logs" | grep -q "log_collector"; then
            sed -i.bak '/log_collector/d' "$POSTGRES_CONFIG_FILE" 2>/dev/null || true
            healing_performed=true
        fi
        
        # Restart if healing was performed
        if [ "$healing_performed" = true ]; then
            log "Restarting PostgreSQL with corrected configuration..."
            docker compose -f "$DOCKER_COMPOSE_FILE" restart postgres
            wait_for_postgres_healthy
            success "PostgreSQL auto-healed and restarted successfully."
        fi
    fi
    
    # Check for container restart loops and fix
    local pg_restarts=$(docker inspect comind-ops-postgres --format '{{.RestartCount}}' 2>/dev/null || echo "0")
    if [ "$pg_restarts" -gt 3 ]; then
        warning "PostgreSQL has restarted $pg_restarts times - investigating..."
        # Force recreation if stuck in restart loop
        log "Recreating PostgreSQL container to break restart loop..."
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate postgres
        healing_performed=true
    fi
    
    # Auto-fix MinIO permission issues
    if ! docker exec comind-ops-minio mc ready local 2>/dev/null; then
        log "MinIO readiness check failed - ensuring bucket permissions..."
        docker compose -f "$DOCKER_COMPOSE_FILE" restart minio-init 2>/dev/null || true
        healing_performed=true
    fi
    
    if [ "$healing_performed" = true ]; then
        success "🔧 External services auto-healing completed successfully."
        log "Waiting for services to stabilize..."
        sleep 10
        status_services
    else
        log "✅ External services are healthy - no healing needed."
    fi
    
    return 0
}

# Auto-heal services function
heal_services() {
    log "🔧 Auto-healing external services..."
    local healing_performed=false
    
    # Check for PostgreSQL config errors and auto-fix
    local pg_logs=$(docker compose -f "$DOCKER_COMPOSE_FILE" logs postgres 2>&1)
    if echo "$pg_logs" | grep -q "unrecognized configuration parameter"; then
        warning "PostgreSQL configuration error detected - auto-fixing..."
        
        # Auto-fix common config issues
        if echo "$pg_logs" | grep -q "log_collector"; then
            sed -i.bak '/log_collector/d' "$POSTGRES_CONFIG_FILE" 2>/dev/null || true
            healing_performed=true
        fi
        
        # Restart if healing was performed
        if [ "$healing_performed" = true ]; then
            log "Restarting PostgreSQL with corrected configuration..."
            docker compose -f "$DOCKER_COMPOSE_FILE" restart postgres
            sleep 5
            success "PostgreSQL auto-healed and restarted successfully."
        fi
    fi
    
    # Check for container restart loops and fix
    local pg_restarts=$(docker inspect comind-ops-postgres --format '{{.RestartCount}}' 2>/dev/null || echo "0")
    if [ "$pg_restarts" -gt 3 ]; then
        warning "PostgreSQL has restarted $pg_restarts times - recreating container..."
        docker compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate postgres
        healing_performed=true
    fi
    
    # Auto-fix MinIO permission issues
    if ! docker exec comind-ops-minio mc ready local 2>/dev/null; then
        log "MinIO readiness check failed - ensuring bucket permissions..."
        docker compose -f "$DOCKER_COMPOSE_FILE" restart minio-init 2>/dev/null || true
        healing_performed=true
    fi
    
    if [ "$healing_performed" = true ]; then
        success "🔧 External services auto-healing completed successfully."
        log "Waiting for services to stabilize..."
        sleep 10
    else
        success "✅ External services are healthy - no healing needed."
    fi
    
    return 0
}
