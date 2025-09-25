#!/bin/bash
set -euo pipefail

# Kubernetes Integration Tests
# Tests Kubernetes manifest integration and deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[K8S-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

SPECIFIC_APP=""
TIMEOUT="${TIMEOUT:-60}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            SPECIFIC_APP="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

cd "$PROJECT_ROOT"

test_kustomize_builds() {
    log "Testing Kustomize builds..."
    
    local test_results=0
    
    # Test base kustomization
    if kubectl kustomize k8s/base/ > /tmp/base-output.yaml 2>/dev/null; then
        success "Base kustomization builds successfully"
    else
        error "Base kustomization build failed"
        test_results=1
    fi
    
    # Test platform kustomization
    if kubectl kustomize k8s/platform/ > /tmp/platform-output.yaml 2>/dev/null; then
        success "Platform kustomization builds successfully"
    else
        error "Platform kustomization build failed"
        test_results=1
    fi
    
    # Validate generated YAML
    for output in /tmp/base-output.yaml /tmp/platform-output.yaml; do
        if [[ -f "$output" ]] && kubectl apply --dry-run=client -f "$output" > /dev/null 2>&1; then
            success "Generated YAML is valid: $(basename "$output")"
        else
            error "Generated YAML is invalid: $(basename "$output")"
            test_results=1
        fi
    done
    
    # Cleanup
    rm -f /tmp/base-output.yaml /tmp/platform-output.yaml
    
    return $test_results
}

test_namespace_creation() {
    log "Testing namespace creation..."
    
    local test_results=0
    local test_namespaces=("test-integration" "test-sample-app")
    
    for ns in "${test_namespaces[@]}"; do
        # Create namespace
        if kubectl create namespace "$ns" 2>/dev/null; then
            success "Namespace created: $ns"
            
            # Verify namespace exists
            if kubectl get namespace "$ns" > /dev/null 2>&1; then
                success "Namespace verified: $ns"
            else
                error "Namespace verification failed: $ns"
                test_results=1
            fi
            
            # Cleanup
            kubectl delete namespace "$ns" --ignore-not-found=true > /dev/null 2>&1
        else
            error "Failed to create namespace: $ns"
            test_results=1
        fi
    done
    
    return $test_results
}

test_rbac_resources() {
    log "Testing RBAC resources..."
    
    local test_results=0
    local rbac_file="k8s/base/rbac.yaml"
    
    if [[ ! -f "$rbac_file" ]]; then
        log "RBAC file not found - skipping RBAC tests"
        return 0
    fi
    
    # Test RBAC validation
    if kubectl apply --dry-run=client -f "$rbac_file" > /dev/null 2>&1; then
        success "RBAC resources are valid"
    else
        error "RBAC resources validation failed"
        test_results=1
    fi
    
    # Create temporary namespace for testing
    local test_ns="test-rbac-$$"
    kubectl create namespace "$test_ns" 2>/dev/null || true
    
    # Apply RBAC resources to test namespace
    if kubectl apply -f "$rbac_file" -n "$test_ns" > /dev/null 2>&1; then
        success "RBAC resources applied successfully"
        
        # Cleanup
        kubectl delete namespace "$test_ns" --ignore-not-found=true > /dev/null 2>&1
    else
        error "RBAC resources application failed"
        kubectl delete namespace "$test_ns" --ignore-not-found=true > /dev/null 2>&1
        test_results=1
    fi
    
    return $test_results
}

test_resource_quotas() {
    log "Testing resource quotas..."
    
    local test_results=0
    local quota_file="k8s/base/resource-quotas.yaml"
    
    if [[ ! -f "$quota_file" ]]; then
        log "Resource quota file not found - skipping quota tests"
        return 0
    fi
    
    # Test quota validation
    if kubectl apply --dry-run=client -f "$quota_file" > /dev/null 2>&1; then
        success "Resource quotas are valid"
    else
        error "Resource quota validation failed"
        test_results=1
    fi
    
    return $test_results
}

test_network_policies() {
    log "Testing network policies..."
    
    local test_results=0
    local netpol_file="k8s/base/network-policies.yaml"
    
    if [[ ! -f "$netpol_file" ]]; then
        log "Network policy file not found - skipping network policy tests"
        return 0
    fi
    
    # Test network policy validation
    if kubectl apply --dry-run=client -f "$netpol_file" > /dev/null 2>&1; then
        success "Network policies are valid"
    else
        error "Network policy validation failed"
        test_results=1
    fi
    
    return $test_results
}

test_helm_chart_deployment() {
    log "Testing Helm chart deployment..."
    
    local test_results=0
    local test_namespace="test-helm-$$"
    
    # Create test namespace
    kubectl create namespace "$test_namespace" 2>/dev/null || true
    
    # Find charts to test
    local charts_to_test=()
    if [[ -n "$SPECIFIC_APP" ]]; then
        if [[ -d "k8s/apps/$SPECIFIC_APP/chart" ]]; then
            charts_to_test=("$SPECIFIC_APP")
        else
            error "Chart not found for app: $SPECIFIC_APP"
            kubectl delete namespace "$test_namespace" --ignore-not-found=true > /dev/null 2>&1
            return 1
        fi
    else
        while IFS= read -r -d '' chart_dir; do
            local app_name=$(basename "$(dirname "$chart_dir")")
            charts_to_test+=("$app_name")
        done < <(find k8s/apps -name chart -type d -print0 2>/dev/null)
    fi
    
    for app_name in "${charts_to_test[@]}"; do
        local chart_dir="k8s/apps/$app_name/chart"
        local values_file="k8s/apps/$app_name/values/dev.yaml"
        
        log "Testing deployment of $app_name..."
        
        # Install chart
        local helm_args=("install" "$app_name" "$chart_dir" "--namespace" "$test_namespace")
        if [[ -f "$values_file" ]]; then
            helm_args+=("-f" "$values_file")
        fi
        
        if timeout "$TIMEOUT" helm "${helm_args[@]}" > /dev/null 2>&1; then
            success "Helm chart installed: $app_name"
            
            # Wait for deployment to be ready
            if kubectl wait --for=condition=available --timeout="${TIMEOUT}s" deployment/"$app_name" -n "$test_namespace" > /dev/null 2>&1; then
                success "Deployment ready: $app_name"
            else
                error "Deployment not ready within timeout: $app_name"
                test_results=1
            fi
            
            # Uninstall chart
            helm uninstall "$app_name" -n "$test_namespace" > /dev/null 2>&1 || true
        else
            error "Helm chart installation failed: $app_name"
            test_results=1
        fi
    done
    
    # Cleanup test namespace
    kubectl delete namespace "$test_namespace" --ignore-not-found=true > /dev/null 2>&1
    
    return $test_results
}

test_service_connectivity() {
    log "Testing service connectivity..."
    
    local test_results=0
    local test_namespace="test-connectivity-$$"
    
    # Create test namespace
    kubectl create namespace "$test_namespace" 2>/dev/null || true
    
    # Deploy a simple test service
    cat << EOF | kubectl apply -n "$test_namespace" -f - > /dev/null 2>&1
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-service
  template:
    metadata:
      labels:
        app: test-service
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test-service
  ports:
  - port: 80
    targetPort: 80
EOF
    
    # Wait for deployment
    if kubectl wait --for=condition=available --timeout="${TIMEOUT}s" deployment/test-service -n "$test_namespace" > /dev/null 2>&1; then
        success "Test service deployed"
        
        # Test service connectivity
        local test_pod="test-client"
        kubectl run "$test_pod" --image=curlimages/curl:latest --rm -i --restart=Never -n "$test_namespace" -- \
            curl -s --connect-timeout 10 http://test-service.${test_namespace}.svc.cluster.local > /dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            success "Service connectivity test passed"
        else
            error "Service connectivity test failed"
            test_results=1
        fi
    else
        error "Test service deployment failed"
        test_results=1
    fi
    
    # Cleanup
    kubectl delete namespace "$test_namespace" --ignore-not-found=true > /dev/null 2>&1
    
    return $test_results
}

test_pod_security() {
    log "Testing pod security policies..."
    
    local test_results=0
    local psp_file="k8s/base/pod-security.yaml"
    
    if [[ ! -f "$psp_file" ]]; then
        log "Pod security file not found - skipping pod security tests"
        return 0
    fi
    
    # Test pod security policy validation
    if kubectl apply --dry-run=client -f "$psp_file" > /dev/null 2>&1; then
        success "Pod security policies are valid"
    else
        error "Pod security policy validation failed"
        test_results=1
    fi
    
    return $test_results
}

# Main test execution
main() {
    log "Starting Kubernetes integration tests..."
    
    # Check if kubectl is available and cluster is accessible
    if ! kubectl cluster-info > /dev/null 2>&1; then
        error "Kubernetes cluster not accessible - skipping integration tests"
        return 1
    fi
    
    local test_results=0
    
    # Run integration tests
    log "Running Kustomize build tests..."
    if ! test_kustomize_builds; then
        test_results=1
    fi
    
    log "Running namespace creation tests..."
    if ! test_namespace_creation; then
        test_results=1
    fi
    
    log "Running RBAC resource tests..."
    if ! test_rbac_resources; then
        test_results=1
    fi
    
    log "Running resource quota tests..."
    if ! test_resource_quotas; then
        test_results=1
    fi
    
    log "Running network policy tests..."
    if ! test_network_policies; then
        test_results=1
    fi
    
    log "Running pod security tests..."
    if ! test_pod_security; then
        test_results=1
    fi
    
    # Only run deployment tests if Helm is available
    if command -v helm &> /dev/null; then
        log "Running Helm chart deployment tests..."
        if ! test_helm_chart_deployment; then
            test_results=1
        fi
        
        log "Running service connectivity tests..."
        if ! test_service_connectivity; then
            test_results=1
        fi
    else
        log "Helm not available - skipping deployment tests"
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "All Kubernetes integration tests passed!"
    else
        error "Some Kubernetes integration tests failed!"
    fi
    
    return $test_results
}

main "$@"
