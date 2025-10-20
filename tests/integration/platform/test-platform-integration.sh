#!/bin/bash
set -euo pipefail

# Platform Services Integration Tests
# Tests integration between platform services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[PLATFORM-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

TIMEOUT="${TIMEOUT:-120}"

cd "$PROJECT_ROOT"

test_platform_manifests() {
    log "Testing platform service manifests..."
    
    local test_results=0
    local platform_dir="k8s/platform"
    
    # Test platform kustomization
    if kubectl kustomize "$platform_dir" > /tmp/platform-manifests.yaml 2>/dev/null; then
        success "Platform kustomization builds successfully"
        
        # Validate generated manifests
        if kubectl apply --dry-run=client -f /tmp/platform-manifests.yaml > /dev/null 2>&1; then
            success "Platform manifests are valid"
        else
            error "Platform manifest validation failed"
            test_results=1
        fi
        
        rm -f /tmp/platform-manifests.yaml
    else
        error "Platform kustomization build failed"
        test_results=1
    fi
    
    return $test_results
}

test_elasticmq_integration() {
    log "Testing ElasticMQ integration..."
    
    local test_results=0
    local elasticmq_dir="k8s/platform/elasticmq"
    
    # Test ElasticMQ deployment manifest
    local deployment_file="$elasticmq_dir/deployment.yaml"
    if [[ -f "$deployment_file" ]]; then
        if kubectl apply --dry-run=client -f "$deployment_file" > /dev/null 2>&1; then
            success "ElasticMQ deployment manifest is valid"
        else
            error "ElasticMQ deployment manifest validation failed"
            test_results=1
        fi
    else
        error "ElasticMQ deployment manifest not found"
        test_results=1
    fi
    
    # Test ElasticMQ values files
    local values_dir="$elasticmq_dir/values"
    if [[ -d "$values_dir" ]]; then
        for values_file in "$values_dir"/*.yaml; do
            if [[ -f "$values_file" ]]; then
                local env=$(basename "$values_file" .yaml)
                if yq eval '.' "$values_file" > /dev/null 2>&1; then
                    success "ElasticMQ values file is valid: $env"
                else
                    error "ElasticMQ values file has errors: $env"
                    test_results=1
                fi
            fi
        done
    fi
    
    return $test_results
}

test_registry_integration() {
    log "Testing Docker Registry integration..."
    
    local test_results=0
    local registry_dir="k8s/platform/registry"
    
    # Test registry manifest
    local registry_file="$registry_dir/registry.yaml"
    if [[ -f "$registry_file" ]]; then
        if kubectl apply --dry-run=client -f "$registry_file" > /dev/null 2>&1; then
            success "Registry manifest is valid"
        else
            error "Registry manifest validation failed"
            test_results=1
        fi
    else
        error "Registry manifest not found"
        test_results=1
    fi
    
    # Test registry cleanup job
    local cleanup_file="$registry_dir/registry-cleanup.yaml"
    if [[ -f "$cleanup_file" ]]; then
        if kubectl apply --dry-run=client -f "$cleanup_file" > /dev/null 2>&1; then
            success "Registry cleanup job manifest is valid"
        else
            error "Registry cleanup job manifest validation failed"
            test_results=1
        fi
    else
        error "Registry cleanup job manifest not found"
        test_results=1
    fi
    
    return $test_results
}

test_backup_integration() {
    log "Testing backup services integration..."
    
    local test_results=0
    local backup_dir="k8s/platform/backups"
    
    # Test PostgreSQL backup job
    local postgres_backup="$backup_dir/postgres-cronjob.yaml"
    if [[ -f "$postgres_backup" ]]; then
        if kubectl apply --dry-run=client -f "$postgres_backup" > /dev/null 2>&1; then
            success "PostgreSQL backup job manifest is valid"
        else
            error "PostgreSQL backup job manifest validation failed"
            test_results=1
        fi
    else
        error "PostgreSQL backup job manifest not found"
        test_results=1
    fi
    
    # Test MinIO backup job
    local minio_backup="$backup_dir/minio-cronjob.yaml"
    if [[ -f "$minio_backup" ]]; then
        if kubectl apply --dry-run=client -f "$minio_backup" > /dev/null 2>&1; then
            success "MinIO backup job manifest is valid"
        else
            error "MinIO backup job manifest validation failed"
            test_results=1
        fi
    else
        error "MinIO backup job manifest not found"
        test_results=1
    fi
    
    return $test_results
}

test_service_dependencies() {
    log "Testing service dependency configuration..."
    
    local test_results=0
    
    # Check if services reference each other correctly
    local platform_manifests
    platform_manifests=$(find k8s/platform -name "*.yaml" -type f)
    
    # Test database references
    if grep -r "DATABASE_HOST\|postgres\|postgresql" k8s/platform/ --include="*.yaml" > /dev/null 2>&1; then
        success "Database service references found"
    else
        log "No database service references found (may be external)"
    fi
    
    # Test storage references
    if grep -r "STORAGE_\|minio\|s3" k8s/platform/ --include="*.yaml" > /dev/null 2>&1; then
        success "Storage service references found"
    else
        log "No storage service references found (may be external)"
    fi
    
    # Test queue references
    if grep -r "QUEUE_\|sqs\|elasticmq" k8s/platform/ --include="*.yaml" > /dev/null 2>&1; then
        success "Queue service references found"
    else
        log "No queue service references found"
    fi
    
    return $test_results
}

test_configuration_consistency() {
    log "Testing configuration consistency across services..."
    
    local test_results=0
    
    # Check for consistent naming conventions
    local service_names=()
    while IFS= read -r -d '' service_dir; do
        local service_name=$(basename "$service_dir")
        service_names+=("$service_name")
    done < <(find k8s/platform -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    for service in "${service_names[@]}"; do
        # Check if service has consistent resource naming
        local service_files=()
        while IFS= read -r -d '' file; do
            service_files+=("$file")
        done < <(find "k8s/platform/$service" -name "*.yaml" -type f -print0 2>/dev/null)
        
        for file in "${service_files[@]}"; do
            # Check if service name appears in resource names
            if grep -q "name:.*$service" "$file"; then
                success "Consistent naming found in $service"
                break
            fi
        done
    done
    
    return $test_results
}

test_platform_deployment_simulation() {
    log "Testing platform deployment simulation..."
    
    local test_results=0
    local test_namespace="test-platform-$$"
    
    # Create test namespace
    kubectl create namespace "$test_namespace" 2>/dev/null || true
    
    # Test platform service deployment (dry run)
    local platform_manifests="/tmp/platform-test-manifests.yaml"
    if kubectl kustomize k8s/platform/ > "$platform_manifests" 2>/dev/null; then
        # Apply manifests with dry-run
        if kubectl apply --dry-run=client -f "$platform_manifests" -n "$test_namespace" > /dev/null 2>&1; then
            success "Platform services would deploy successfully"
        else
            error "Platform service deployment simulation failed"
            test_results=1
        fi
        
        # Check for resource conflicts (same name + same kind = conflict)
        # Extract kind and name pairs, then check for duplicates
        local temp_file="/tmp/kind-name-pairs-$$"
        awk '/^kind:/ { kind=$2 } /^  name:/ { if (kind != "") print kind":"$2; kind="" }' "$platform_manifests" > "$temp_file"
        
        local duplicate_resources
        duplicate_resources=$(sort "$temp_file" | uniq -d)
        
        if [[ -z "$duplicate_resources" ]]; then
            success "No duplicate resources found (same kind+name)"
        else
            error "Duplicate resources found (same kind+name): $duplicate_resources"
            test_results=1
        fi
        
        rm -f "$temp_file"
        
        rm -f "$platform_manifests"
    else
        error "Failed to generate platform manifests"
        test_results=1
    fi
    
    # Cleanup test namespace
    kubectl delete namespace "$test_namespace" --ignore-not-found=true > /dev/null 2>&1
    
    return $test_results
}

test_resource_requirements() {
    log "Testing platform service resource requirements..."
    
    local test_results=0
    
    # Check if services have resource limits defined
    local services_with_resources=0
    local total_services=0
    
    while IFS= read -r -d '' manifest_file; do
        # Skip kustomization files
        if [[ "$(basename "$manifest_file")" == "kustomization.yaml" ]]; then
            continue
        fi
        
        if grep -q "kind: Deployment\|kind: StatefulSet\|kind: DaemonSet" "$manifest_file"; then
            total_services=$((total_services + 1))
            
            if grep -A 50 "containers:" "$manifest_file" | grep -q "resources:"; then
                services_with_resources=$((services_with_resources + 1))
            fi
        fi
    done < <(find k8s/platform -name "*.yaml" -type f -print0 2>/dev/null)
    
    if [[ $total_services -gt 0 ]]; then
        local resource_coverage=$((services_with_resources * 100 / total_services))
        if [[ $resource_coverage -ge 80 ]]; then
            success "Good resource definition coverage: $resource_coverage% ($services_with_resources/$total_services)"
        else
            error "Low resource definition coverage: $resource_coverage% ($services_with_resources/$total_services)"
            test_results=1
        fi
    else
        log "No platform services found with resource requirements"
    fi
    
    return $test_results
}

test_health_checks() {
    log "Testing platform service health check configuration..."
    
    local test_results=0
    
    # Check for health check probes in deployments
    local deployments_with_probes=0
    local total_deployments=0
    
    while IFS= read -r -d '' manifest_file; do
        # Skip kustomization files
        if [[ "$(basename "$manifest_file")" == "kustomization.yaml" ]]; then
            continue
        fi
        
        if grep -q "kind: Deployment" "$manifest_file"; then
            total_deployments=$((total_deployments + 1))
            
            if grep -A 50 "containers:" "$manifest_file" | grep -q "livenessProbe\|readinessProbe"; then
                deployments_with_probes=$((deployments_with_probes + 1))
            fi
        fi
    done < <(find k8s/platform -name "*.yaml" -type f -print0 2>/dev/null)
    
    if [[ $total_deployments -gt 0 ]]; then
        local probe_coverage=$((deployments_with_probes * 100 / total_deployments))
        if [[ $probe_coverage -ge 70 ]]; then
            success "Good health check coverage: $probe_coverage% ($deployments_with_probes/$total_deployments)"
        else
            error "Low health check coverage: $probe_coverage% ($deployments_with_probes/$total_deployments)"
            test_results=1
        fi
    else
        log "No deployments found for health check analysis"
    fi
    
    return $test_results
}

# Main test execution
main() {
    log "Starting platform services integration tests..."
    
    # Check dependencies
    local deps_available=true
    if ! command -v yq &> /dev/null; then
        log "yq not available - some tests will be limited"
        deps_available=false
    fi
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not available - skipping Kubernetes tests"
        return 1
    fi
    
    local test_results=0
    
    # Run platform integration tests
    if ! test_platform_manifests; then
        test_results=1
    fi
    
    if ! test_elasticmq_integration; then
        test_results=1
    fi
    
    if ! test_registry_integration; then
        test_results=1
    fi
    
    if ! test_backup_integration; then
        test_results=1
    fi
    
    if ! test_service_dependencies; then
        test_results=1
    fi
    
    if ! test_configuration_consistency; then
        test_results=1
    fi
    
    if ! test_platform_deployment_simulation; then
        test_results=1
    fi
    
    if ! test_resource_requirements; then
        test_results=1
    fi
    
    if ! test_health_checks; then
        test_results=1
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "All platform integration tests passed!"
    else
        error "Some platform integration tests failed!"
    fi
    
    return $test_results
}

main "$@"
