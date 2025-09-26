#!/bin/bash
set -euo pipefail

# Platform Load Testing
# Tests platform performance under load

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[LOAD-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

cd "$PROJECT_ROOT"

# Test configuration
TIMEOUT="${TIMEOUT:-300}"
TEST_NAMESPACE="load-test-$$"
CLEANUP="${CLEANUP:-true}"

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test resources..."
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true > /dev/null 2>&1 || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT

test_helm_chart_performance() {
    log "Testing Helm chart deployment performance..."
    
    local test_results=0
    
    # Create test namespace
    kubectl create namespace "$TEST_NAMESPACE" > /dev/null 2>&1
    
    # Test monitoring dashboard deployment time
    local start_time=$(date +%s)
    
    if helm install monitoring-dashboard-load k8s/charts/apps/monitoring-dashboard \
        --namespace "$TEST_NAMESPACE" \
        --set replicaCount=1 \
        --set resources.requests.memory=64Mi \
        --set resources.requests.cpu=50m \
        --timeout 60s > /dev/null 2>&1; then
        
        local end_time=$(date +%s)
        local deployment_time=$((end_time - start_time))
        
        if [[ $deployment_time -lt 30 ]]; then
            success "Monitoring dashboard deployed in ${deployment_time}s (target: <30s)"
        else
            error "Monitoring dashboard deployment took ${deployment_time}s (target: <30s)"
            test_results=1
        fi
        
        # Cleanup
        helm uninstall monitoring-dashboard-load -n "$TEST_NAMESPACE" > /dev/null 2>&1 || true
    else
        error "Monitoring dashboard deployment failed"
        test_results=1
    fi
    
    return $test_results
}

test_kubectl_performance() {
    log "Testing kubectl command performance..."
    
    local test_results=0
    
    # Test kubectl response time
    local start_time=$(date +%s)
    
    for i in {1..10}; do
        kubectl get nodes > /dev/null 2>&1
    done
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local avg_time=$((total_time * 100 / 10))  # Convert to centiseconds
    
    if [[ $avg_time -lt 50 ]]; then  # Less than 0.5 seconds average
        success "kubectl commands average ${avg_time}cs (target: <50cs)"
    else
        error "kubectl commands average ${avg_time}cs (target: <50cs)"
        test_results=1
    fi
    
    return $test_results
}

test_helm_template_performance() {
    log "Testing Helm template rendering performance..."
    
    local test_results=0
    
    # Test template rendering time for each chart
    local charts=("k8s/apps/test-api/chart" "k8s/apps/my-api/chart" "k8s/charts/apps/monitoring-dashboard")
    
    for chart in "${charts[@]}"; do
        if [[ -d "$chart" ]]; then
            local start_time=$(date +%s)
            
            if helm template test-chart "$chart" > /dev/null 2>&1; then
                local end_time=$(date +%s)
                local render_time=$((end_time - start_time))
                
                if [[ $render_time -lt 5 ]]; then
                    success "Chart $(basename "$chart") rendered in ${render_time}s (target: <5s)"
                else
                    error "Chart $(basename "$chart") rendered in ${render_time}s (target: <5s)"
                    test_results=1
                fi
            else
                error "Chart $(basename "$chart") template rendering failed"
                test_results=1
            fi
        fi
    done
    
    return $test_results
}

test_kustomize_performance() {
    log "Testing Kustomize build performance..."
    
    local test_results=0
    
    # Test kustomize build time
    local kustomizations=("k8s/base" "k8s/platform")
    
    for kustomization in "${kustomizations[@]}"; do
        if [[ -d "$kustomization" ]]; then
            local start_time=$(date +%s)
            
            if kubectl kustomize "$kustomization" > /dev/null 2>&1; then
                local end_time=$(date +%s)
                local build_time=$((end_time - start_time))
                
                if [[ $build_time -lt 10 ]]; then
                    success "Kustomization $(basename "$kustomization") built in ${build_time}s (target: <10s)"
                else
                    error "Kustomization $(basename "$kustomization") built in ${build_time}s (target: <10s)"
                    test_results=1
                fi
            else
                error "Kustomization $(basename "$kustomization") build failed"
                test_results=1
            fi
        fi
    done
    
    return $test_results
}

test_terraform_performance() {
    log "Testing Terraform operation performance..."
    
    local test_results=0
    
    # Test terraform validate performance
    local terraform_dirs=("infra/terraform/modules/app_skel" "infra/terraform/environments/local")
    
    for tf_dir in "${terraform_dirs[@]}"; do
        if [[ -d "$tf_dir" ]]; then
            local start_time=$(date +%s)
            
            if bash -c "export GVM_DEBUG='' && cd '$tf_dir' && terraform validate" > /dev/null 2>&1; then
                local end_time=$(date +%s)
                local validate_time=$((end_time - start_time))
                
                if [[ $validate_time -lt 15 ]]; then
                    success "Terraform $(basename "$tf_dir") validated in ${validate_time}s (target: <15s)"
                else
                    error "Terraform $(basename "$tf_dir") validated in ${validate_time}s (target: <15s)"
                    test_results=1
                fi
            else
                error "Terraform $(basename "$tf_dir") validation failed"
                test_results=1
            fi
        fi
    done
    
    return $test_results
}

test_script_performance() {
    log "Testing script execution performance..."
    
    local test_results=0
    
    # Test script execution time
    local scripts=("scripts/new-app.sh" "scripts/seal-secret.sh" "infra/terraform/scripts/tf.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            local start_time=$(date +%s)
            
            if timeout 10s "$script" --help > /dev/null 2>&1; then
                local end_time=$(date +%s)
                local exec_time=$((end_time - start_time))
                
                if [[ $exec_time -lt 3 ]]; then
                    success "Script $(basename "$script") help in ${exec_time}s (target: <3s)"
                else
                    error "Script $(basename "$script") help in ${exec_time}s (target: <3s)"
                    test_results=1
                fi
            else
                error "Script $(basename "$script") execution failed"
                test_results=1
            fi
        fi
    done
    
    return $test_results
}

# Main test execution
main() {
    log "Starting platform load testing..."
    log "Test namespace: $TEST_NAMESPACE"
    log "Timeout: ${TIMEOUT}s"
    
    local test_results=0
    
    # Run performance tests
    if ! test_kubectl_performance; then
        test_results=1
    fi
    
    if ! test_helm_template_performance; then
        test_results=1
    fi
    
    if ! test_kustomize_performance; then
        test_results=1
    fi
    
    if ! test_terraform_performance; then
        test_results=1
    fi
    
    if ! test_script_performance; then
        test_results=1
    fi
    
    if ! test_helm_chart_performance; then
        test_results=1
    fi
    
    # Final results
    echo
    log "Load Test Results:"
    echo "================="
    
    if [[ $test_results -eq 0 ]]; then
        success "All performance tests passed! 🚀"
        log "Platform performance is within acceptable limits."
    else
        error "Some performance tests failed! ⚠️"
        log "Platform performance may need optimization."
    fi
    
    return $test_results
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --timeout SECONDS    Test timeout (default: 300)"
            echo "  --no-cleanup         Skip cleanup after tests"
            echo "  --help               Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main "$@"
