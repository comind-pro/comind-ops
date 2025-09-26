#!/bin/bash
set -euo pipefail

# End-to-End Platform Deployment Test
# Tests complete platform deployment and functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[E2E-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

cd "$PROJECT_ROOT"

# Test configuration
TIMEOUT="${TIMEOUT:-300}"
TEST_NAMESPACE="e2e-test-$$"
CLEANUP="${CLEANUP:-true}"

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test resources..."
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true > /dev/null 2>&1 || true
        # Clean up any other test resources
        kubectl delete namespace "test-*" --ignore-not-found=true > /dev/null 2>&1 || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT

test_platform_bootstrap() {
    log "Testing platform bootstrap process..."
    
    local test_results=0
    
    # Test if we can run bootstrap (dry run)
    if make bootstrap --dry-run > /dev/null 2>&1; then
        success "Bootstrap command is available"
    else
        error "Bootstrap command not available or failed"
        test_results=1
    fi
    
    # Test dependency checking
    if make check-deps > /dev/null 2>&1; then
        success "Dependency check passed"
    else
        error "Dependency check failed"
        test_results=1
    fi
    
    return $test_results
}

test_kubernetes_cluster() {
    log "Testing Kubernetes cluster connectivity..."
    
    local test_results=0
    
    # Test cluster connectivity
    if kubectl cluster-info > /dev/null 2>&1; then
        success "Kubernetes cluster is accessible"
    else
        error "Cannot connect to Kubernetes cluster"
        test_results=1
        return $test_results
    fi
    
    # Test cluster version
    local k8s_version=$(kubectl version --short --client 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    log "Kubernetes version: $k8s_version"
    
    # Test namespace creation
    if kubectl create namespace "$TEST_NAMESPACE" > /dev/null 2>&1; then
        success "Test namespace created: $TEST_NAMESPACE"
    else
        error "Failed to create test namespace"
        test_results=1
    fi
    
    return $test_results
}

test_helm_charts() {
    log "Testing Helm chart deployments..."
    
    local test_results=0
    
    # Test monitoring dashboard chart
    if helm install monitoring-dashboard-test k8s/charts/apps/monitoring-dashboard \
        --namespace "$TEST_NAMESPACE" \
        --set replicaCount=1 \
        --set resources.requests.memory=64Mi \
        --set resources.requests.cpu=50m \
        --timeout 60s > /dev/null 2>&1; then
        success "Monitoring dashboard chart deployed"
        
        # Wait for deployment
        if kubectl wait --for=condition=available --timeout=60s \
            deployment/monitoring-dashboard-test -n "$TEST_NAMESPACE" > /dev/null 2>&1; then
            success "Monitoring dashboard deployment ready"
        else
            error "Monitoring dashboard deployment not ready"
            test_results=1
        fi
        
        # Cleanup
        helm uninstall monitoring-dashboard-test -n "$TEST_NAMESPACE" > /dev/null 2>&1 || true
    else
        error "Monitoring dashboard chart deployment failed"
        test_results=1
    fi
    
    return $test_results
}

test_platform_services() {
    log "Testing platform services..."
    
    local test_results=0
    
    # Test if platform services can be deployed
    local services=("elasticmq" "registry")
    
    for service in "${services[@]}"; do
        if [[ -d "k8s/platform/$service" ]]; then
            if kubectl apply -f "k8s/platform/$service" --dry-run=client > /dev/null 2>&1; then
                success "Platform service $service manifests are valid"
            else
                error "Platform service $service manifests are invalid"
                test_results=1
            fi
        else
            log "Platform service $service directory not found"
        fi
    done
    
    return $test_results
}

test_gitops_structure() {
    log "Testing GitOps structure..."
    
    local test_results=0
    
    # Test ArgoCD project
    if [[ -f "argo/projects/platform-project.yaml" ]]; then
        if kubectl apply -f "argo/projects/platform-project.yaml" --dry-run=client > /dev/null 2>&1; then
            success "ArgoCD project manifest is valid"
        else
            error "ArgoCD project manifest is invalid"
            test_results=1
        fi
    else
        error "ArgoCD project manifest not found"
        test_results=1
    fi
    
    # Test kustomization files
    local kustomizations=("k8s/base/kustomization.yaml" "k8s/platform/kustomization.yaml")
    
    for kustomization in "${kustomizations[@]}"; do
        if [[ -f "$kustomization" ]]; then
            if kubectl kustomize "$(dirname "$kustomization")" > /dev/null 2>&1; then
                success "Kustomization builds: $(basename "$(dirname "$kustomization")")"
            else
                error "Kustomization build failed: $(basename "$(dirname "$kustomization")")"
                test_results=1
            fi
        else
            error "Kustomization file not found: $kustomization"
            test_results=1
        fi
    done
    
    return $test_results
}

test_application_deployment() {
    log "Testing application deployment process..."
    
    local test_results=0
    
    # Test new app creation (dry run)
    if make new-app APP=test-e2e-app TEAM=test --dry-run > /dev/null 2>&1; then
        success "New app creation command available"
    else
        log "New app creation command not available (may require interactive input)"
    fi
    
    # Test if app charts exist and are valid
    local app_charts=("test-api" "my-api")
    
    for app in "${app_charts[@]}"; do
        if [[ -d "k8s/apps/$app/chart" ]]; then
            if helm lint "k8s/apps/$app/chart" > /dev/null 2>&1; then
                success "App chart $app is valid"
            else
                error "App chart $app is invalid"
                test_results=1
            fi
        else
            log "App chart $app not found"
        fi
    done
    
    return $test_results
}

test_security_compliance() {
    log "Testing security compliance..."
    
    local test_results=0
    
    # Test pod security standards
    if [[ -f "k8s/base/pod-security.yaml" ]]; then
        if kubectl apply -f "k8s/base/pod-security.yaml" --dry-run=client > /dev/null 2>&1; then
            success "Pod security policies are valid"
        else
            error "Pod security policies are invalid"
            test_results=1
        fi
    else
        error "Pod security policies not found"
        test_results=1
    fi
    
    # Test network policies
    if [[ -f "k8s/base/network-policies.yaml" ]]; then
        if kubectl apply -f "k8s/base/network-policies.yaml" --dry-run=client > /dev/null 2>&1; then
            success "Network policies are valid"
        else
            error "Network policies are invalid"
            test_results=1
        fi
    else
        error "Network policies not found"
        test_results=1
    fi
    
    return $test_results
}

# Main test execution
main() {
    log "Starting end-to-end platform deployment test..."
    log "Test namespace: $TEST_NAMESPACE"
    log "Timeout: ${TIMEOUT}s"
    
    local test_results=0
    
    # Run test suites
    if ! test_platform_bootstrap; then
        test_results=1
    fi
    
    if ! test_kubernetes_cluster; then
        test_results=1
    fi
    
    if ! test_helm_charts; then
        test_results=1
    fi
    
    if ! test_platform_services; then
        test_results=1
    fi
    
    if ! test_gitops_structure; then
        test_results=1
    fi
    
    if ! test_application_deployment; then
        test_results=1
    fi
    
    if ! test_security_compliance; then
        test_results=1
    fi
    
    # Final results
    echo
    log "End-to-End Test Results:"
    echo "======================="
    
    if [[ $test_results -eq 0 ]]; then
        success "All end-to-end tests passed! 🎉"
        log "Platform is ready for deployment."
    else
        error "Some end-to-end tests failed! ❌"
        log "Please review the test results and fix any issues."
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
