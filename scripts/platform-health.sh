#!/bin/bash

# Comind-Ops Platform - Health Check and Auto-Recovery Script
# Comprehensive platform diagnostics and healing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[HEALTH]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Health check functions
check_external_services() {
    log "Checking external services health..."
    local issues_found=false
    
    # Check PostgreSQL
    if docker ps --filter name=comind-ops-postgres --format "{{.Status}}" | grep -q "Up.*healthy"; then
        success "PostgreSQL: Healthy"
    elif docker ps --filter name=comind-ops-postgres | grep -q comind-ops-postgres; then
        warning "PostgreSQL: Running but not healthy - attempting auto-heal"
        "$SCRIPT_DIR/external-services.sh" heal
        issues_found=true
    else
        error "PostgreSQL: Not running"
        issues_found=true
    fi
    
    # Check MinIO
    if docker ps --filter name=comind-ops-minio --format "{{.Status}}" | grep -q "Up.*healthy"; then
        success "MinIO: Healthy"
    else
        warning "MinIO: Issues detected"
        issues_found=true
    fi
    
    return $([ "$issues_found" = false ] && echo 0 || echo 1)
}

check_kubernetes_cluster() {
    log "Checking Kubernetes cluster health..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Kubernetes cluster not accessible"
        return 1
    fi
    
    # Check core components
    local components=("kube-system" "argocd" "ingress-nginx" "metallb-system")
    for component in "${components[@]}"; do
        if kubectl get pods -n "$component" --no-headers 2>/dev/null | grep -q "Running\|Completed"; then
            success "Namespace $component: Healthy"
        else
            warning "Namespace $component: Issues detected"
        fi
    done
    
    return 0
}

check_platform_services() {
    log "Checking platform service endpoints..."
    
    # Check ArgoCD
    if curl -s -o /dev/null -w "%{http_code}" "http://argocd.dev.127.0.0.1.nip.io:8080" | grep -q "200\|302"; then
        success "ArgoCD: Accessible"
    else
        warning "ArgoCD: Not accessible via ingress"
    fi
    
    # Check MinIO console
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:9001" | grep -q "200\|302"; then
        success "MinIO Console: Accessible"
    else
        warning "MinIO Console: Not accessible"
    fi
}

auto_heal_platform() {
    log "🔧 Starting comprehensive platform auto-healing..."
    local healing_performed=false
    
    # 1. Heal external services (delegate to specialized script)
    log "Step 1: Healing external services..."
    if "$SCRIPT_DIR/external-services.sh" heal; then
        success "External services healing completed"
    else
        warning "External services healing had issues, continuing with other components"
    fi
    
    # 2. Check for stuck Kubernetes pods and restart them
    log "Step 2: Checking for stuck Kubernetes pods..."
    local stuck_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || true)
    if [ -n "$stuck_pods" ]; then
        warning "Found stuck pods - attempting restart..."
        echo "$stuck_pods" | while read -r namespace pod rest; do
            if [ -n "$namespace" ] && [ -n "$pod" ]; then
                log "Restarting stuck pod: $pod in namespace $namespace"
                kubectl delete pod "$pod" -n "$namespace" --ignore-not-found=true
                healing_performed=true
            fi
        done
    else
        log "All Kubernetes pods are in healthy state"
    fi
    
    # 3. Check and heal ingress connectivity
    log "Step 3: Validating ingress connectivity..."
    if ! curl -s -o /dev/null -w "%{http_code}" "http://argocd.dev.127.0.0.1.nip.io:8080" | grep -q "200\|302"; then
        warning "ArgoCD ingress not accessible - restarting ingress-nginx..."
        kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx 2>/dev/null || true
        healing_performed=true
        sleep 10 # Wait for ingress to stabilize
    else
        log "Ingress connectivity is healthy"
    fi
    
    # 4. Check and heal ArgoCD if needed
    log "Step 4: Checking ArgoCD health..."
    local argocd_pods_ready=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$argocd_pods_ready" -eq 0 ]; then
        warning "ArgoCD server not running - attempting restart..."
        kubectl rollout restart deployment/argocd-server -n argocd 2>/dev/null || true
        healing_performed=true
    else
        log "ArgoCD is running normally"
    fi
    
    if [ "$healing_performed" = true ]; then
        success "🔧 Platform auto-healing completed with corrections applied"
        log "Waiting for services to stabilize..."
        sleep 15
    else
        success "✅ Platform is healthy - no healing actions required"
    fi
    
    return 0
}

generate_health_report() {
    log "Generating platform health report..."
    
    cat > "$PROJECT_ROOT/platform-health-report.md" << 'REPORT'
# Comind-Ops Platform Health Report

Generated: $(date)

## External Services Status
- PostgreSQL: $(docker ps --filter name=comind-ops-postgres --format "{{.Status}}" || echo "Not running")
- MinIO: $(docker ps --filter name=comind-ops-minio --format "{{.Status}}" || echo "Not running")

## Kubernetes Cluster Status
- Cluster: $(kubectl cluster-info --request-timeout=5s >/dev/null 2>&1 && echo "Accessible" || echo "Not accessible")
- ArgoCD: $(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0") pods running
- Ingress: $(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || echo "0") pods running

## Platform URLs
- ArgoCD: http://argocd.dev.127.0.0.1.nip.io:8080
- MinIO Console: http://localhost:9001

## Recommendations
- Run 'make services-start' if external services are down
- Run 'scripts/platform-health.sh --heal' for auto-recovery
- Check logs with 'make services-logs' for diagnostics
REPORT

    success "Health report generated: platform-health-report.md"
}

# Main execution
main() {
    case "${1:-check}" in
        "check")
            log "🔍 Running comprehensive platform health check..."
            check_external_services
            check_kubernetes_cluster  
            check_platform_services
            generate_health_report
            success "✅ Platform health check completed"
            ;;
        "heal")
            log "🔧 Running platform auto-healing..."
            auto_heal_platform
            ;;
        "report")
            generate_health_report
            ;;
        *)
            echo "Usage: $0 [check|heal|report]"
            echo "  check  - Run health checks (default)"
            echo "  heal   - Auto-heal platform issues"  
            echo "  report - Generate health report"
            exit 1
            ;;
    esac
}

main "$@"
