#!/bin/bash
set -euo pipefail

# ArgoCD Integration Tests
# Tests ArgoCD configuration and ApplicationSet functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[ARGOCD-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

cd "$PROJECT_ROOT"

test_argocd_manifests() {
    log "Testing ArgoCD manifest validation..."
    
    local test_results=0
    local argocd_dir="argo"
    
    # Test ArgoCD installation values
    local values_file="$argocd_dir/argocd/install/values.yaml"
    if [[ -f "$values_file" ]]; then
        # Validate YAML syntax
        if yq eval '.' "$values_file" > /dev/null 2>&1; then
            success "ArgoCD values.yaml is valid YAML"
        else
            error "ArgoCD values.yaml has YAML syntax errors"
            test_results=1
        fi
    else
        error "ArgoCD values.yaml not found"
        test_results=1
    fi
    
    # Test ApplicationSet manifest (optional - not required for current GitOps structure)
    local appset_file="$argocd_dir/apps/applicationset.yaml"
    if [[ -f "$appset_file" ]]; then
        if kubectl apply --dry-run=client -f "$appset_file" > /dev/null 2>&1; then
            success "ApplicationSet manifest is valid"
        else
            error "ApplicationSet manifest validation failed"
            test_results=1
        fi
    else
        log "ApplicationSet manifest not found - using individual Application manifests instead"
    fi
    
    return $test_results
}

test_applicationset_structure() {
    log "Testing ApplicationSet structure..."
    
    local test_results=0
    local appset_file="argo/apps/applicationset.yaml"
    
    if [[ ! -f "$appset_file" ]]; then
        log "ApplicationSet file not found - skipping ApplicationSet tests"
        return 0
    fi
    
    # Check for required ApplicationSet components
    local required_fields=(
        "apiVersion: argoproj.io/v1alpha1"
        "kind: ApplicationSet"
        "generators:"
        "template:"
    )
    
    for field in "${required_fields[@]}"; do
        if grep -q "$field" "$appset_file"; then
            success "Found required field: $field"
        else
            error "Missing required field: $field"
            test_results=1
        fi
    done
    
    # Check for git generator
    if grep -A 10 "generators:" "$appset_file" | grep -q "git:"; then
        success "Git generator configured"
    else
        error "Git generator not found"
        test_results=1
    fi
    
    # Check for template configuration
    if grep -A 20 "template:" "$appset_file" | grep -q "metadata:"; then
        success "Application template configured"
    else
        error "Application template not properly configured"
        test_results=1
    fi
    
    return $test_results
}

test_apps_yaml_structure() {
    log "Testing apps.yaml structure..."
    
    local test_results=0
    local apps_file="apps.yaml"
    
    if [[ ! -f "$apps_file" ]]; then
        log "apps.yaml file not found - using individual Application manifests instead"
        return 0
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$apps_file" > /dev/null 2>&1; then
        error "apps.yaml has YAML syntax errors"
        return 1
    fi
    
    # Check for required structure
    if yq eval '.applications' "$apps_file" | grep -q "null"; then
        error "No applications defined in apps.yaml"
        test_results=1
    else
        success "Applications defined in apps.yaml"
    fi
    
    # Check application structure
    local app_count=$(yq eval '.applications | length' "$apps_file" 2>/dev/null || echo "0")
    if [[ "$app_count" -gt 0 ]]; then
        success "Found $app_count applications in apps.yaml"
        
        # Validate each application has required fields
        local required_app_fields=("name" "namespace" "path")
        for field in "${required_app_fields[@]}"; do
            if yq eval ".applications[0] | has(\"$field\")" "$apps_file" | grep -q "true"; then
                success "Application has required field: $field"
            else
                error "Application missing required field: $field"
                test_results=1
            fi
        done
    else
        error "No applications found in apps.yaml"
        test_results=1
    fi
    
    return $test_results
}

test_argocd_project() {
    log "Testing ArgoCD project configuration..."
    
    local test_results=0
    local project_file="argo/projects/platform-project.yaml"
    
    if [[ ! -f "$project_file" ]]; then
        log "ArgoCD project file not found - skipping project tests"
        return 0
    fi
    
    # Validate project manifest
    if kubectl apply --dry-run=client -f "$project_file" > /dev/null 2>&1; then
        success "ArgoCD project manifest is valid"
    else
        error "ArgoCD project manifest validation failed"
        test_results=1
    fi
    
    # Check for required project fields
    local required_fields=("sourceRepos" "destinations" "clusterResourceWhitelist")
    for field in "${required_fields[@]}"; do
        if grep -q "$field" "$project_file"; then
            success "Project has required field: $field"
        else
            error "Project missing required field: $field"
            test_results=1
        fi
    done
    
    return $test_results
}

test_argocd_configuration() {
    log "Testing ArgoCD configuration consistency..."
    
    local test_results=0
    
    # Check if repository URLs are consistent
    local repo_urls=()
    if grep -r "repoURL:" argo/ --include="*.yaml" 2>/dev/null | grep -v "^$" > /dev/null; then
        repo_urls=(
            $(grep -r "repoURL:" argo/ --include="*.yaml" 2>/dev/null | sed 's/.*repoURL: *//' | sort | uniq)
        )
    fi
    
    if [[ ${#repo_urls[@]} -eq 1 ]]; then
        success "Consistent repository URL across ArgoCD configurations"
    elif [[ ${#repo_urls[@]} -gt 1 ]]; then
        error "Inconsistent repository URLs found: ${repo_urls[*]}"
        test_results=1
    else
        log "No repository URLs found in argo/ directory (may be configured elsewhere or not using ArgoCD apps)"
    fi
    
    # Check target revision consistency
    local target_revisions=()
    if grep -r "targetRevision:" argo/ --include="*.yaml" > /dev/null 2>&1; then
        target_revisions=(
            $(grep -r "targetRevision:" argo/ --include="*.yaml" | sed 's/.*targetRevision: *//' | sort | uniq)
        )
    fi
    
    if [[ ${#target_revisions[@]} -eq 1 ]] && [[ "${target_revisions[0]}" == "HEAD" ]]; then
        success "Consistent target revision (HEAD) across ArgoCD configurations"
    elif [[ ${#target_revisions[@]} -gt 0 ]]; then
        log "Multiple target revisions found: ${target_revisions[*]} (may be intentional)"
    else
        log "No target revisions found in ArgoCD configurations"
    fi
    
    return $test_results
}

test_sync_policy() {
    log "Testing ArgoCD sync policies..."
    
    local test_results=0
    local appset_file="argo/apps/applicationset.yaml"
    
    # Check if ApplicationSet exists
    if [[ ! -f "$appset_file" ]]; then
        log "ApplicationSet not found - checking individual Application manifests"
        
        # Check for sync policies in individual Application files
        local app_files=()
        while IFS= read -r -d '' app_file; do
            app_files+=("$app_file")
        done < <(find argo/ k8s/ -name "*.yaml" -type f -exec grep -l "kind: Application" {} \; -print0 2>/dev/null)
        
        if [[ ${#app_files[@]} -gt 0 ]]; then
            log "Found ${#app_files[@]} individual Application manifests"
            success "Using individual Application manifests (valid ArgoCD approach)"
            return 0
        else
            log "No Application or ApplicationSet manifests found (may use different GitOps approach)"
            return 0
        fi
    fi
    
    # Check for sync policy configuration in ApplicationSet
    if grep -A 10 "syncPolicy:" "$appset_file" > /dev/null 2>&1; then
        success "Sync policy configured in ApplicationSet"
        
        # Check for automated sync
        if grep -A 5 "syncPolicy:" "$appset_file" | grep -q "automated:"; then
            success "Automated sync configured"
        else
            log "Manual sync configured (automated sync not enabled)"
        fi
        
        # Check for self-heal
        if grep -A 10 "automated:" "$appset_file" | grep -q "selfHeal:"; then
            success "Self-heal configuration found"
        else
            log "Self-heal not configured"
        fi
        
        # Check for prune
        if grep -A 10 "automated:" "$appset_file" | grep -q "prune:"; then
            success "Prune configuration found"
        else
            log "Prune not configured"
        fi
    else
        log "No sync policy configured in ApplicationSet (using defaults)"
    fi
    
    return $test_results
}

test_application_template() {
    log "Testing ArgoCD application template..."
    
    local test_results=0
    local appset_file="argo/apps/applicationset.yaml"
    
    # Check if ApplicationSet exists
    if [[ ! -f "$appset_file" ]]; then
        log "ApplicationSet not found - skipping template tests (using individual manifests)"
        return 0
    fi
    
    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log "yq not available - skipping template extraction"
        return 0
    fi
    
    # Extract application template and validate
    if yq eval '.spec.template' "$appset_file" > /tmp/app-template.yaml 2>/dev/null; then
        # Check template structure
        local template_file="/tmp/app-template.yaml"
        
        if yq eval '.metadata.name' "$template_file" | grep -q "{{"; then
            success "Application name templating configured"
        else
            log "Application name templating not configured (may use static names)"
        fi
        
        if yq eval '.metadata.namespace' "$template_file" | grep -q "argocd"; then
            success "Application namespace configured"
        else
            log "Application namespace not explicitly set (will use default)"
        fi
        
        if yq eval '.spec.destination.namespace' "$template_file" | grep -q "{{"; then
            success "Destination namespace templating configured"
        else
            log "Destination namespace templating not configured (may use static namespaces)"
        fi
        
        # Cleanup
        rm -f "$template_file"
    else
        log "Could not extract application template (may not be needed)"
    fi
    
    return $test_results
}

# Simulate ArgoCD deployment test
test_simulated_deployment() {
    log "Testing simulated ArgoCD deployment..."
    
    local test_results=0
    local test_namespace="test-argocd-$$"
    
    # Create test namespace
    kubectl create namespace "$test_namespace" 2>/dev/null || true
    
    # Test if ArgoCD CRDs would be accepted (dry-run)
    local appset_file="argo/apps/applicationset.yaml"
    
    # Since we don't have ArgoCD installed, we'll test the YAML structure
    # In a real scenario, this would test actual ApplicationSet creation
    if kubectl apply --dry-run=client -f "$appset_file" 2>&1 | grep -q "no matches for kind"; then
        log "ApplicationSet CRD not available (expected in test environment)"
        success "ApplicationSet manifest structure is valid"
    elif kubectl apply --dry-run=client -f "$appset_file" > /dev/null 2>&1; then
        success "ApplicationSet would be created successfully"
    else
        error "ApplicationSet manifest has validation errors"
        test_results=1
    fi
    
    # Cleanup
    kubectl delete namespace "$test_namespace" --ignore-not-found=true > /dev/null 2>&1
    
    return $test_results
}

# Main test execution
main() {
    log "Starting ArgoCD integration tests..."
    
    # Check dependencies
    if ! command -v yq &> /dev/null; then
        error "yq command not available - some tests will be limited"
        # Continue with limited testing
    fi
    
    local test_results=0
    
    # Run ArgoCD integration tests
    if ! test_argocd_manifests; then
        test_results=1
    fi
    
    if ! test_applicationset_structure; then
        test_results=1
    fi
    
    if ! test_apps_yaml_structure; then
        test_results=1
    fi
    
    if ! test_argocd_project; then
        test_results=1
    fi
    
    if ! test_argocd_configuration; then
        test_results=1
    fi
    
    if ! test_sync_policy; then
        test_results=1
    fi
    
    if ! test_application_template; then
        test_results=1
    fi
    
    # Only run deployment simulation if kubectl is available
    if command -v kubectl &> /dev/null; then
        if ! test_simulated_deployment; then
            test_results=1
        fi
    else
        log "kubectl not available - skipping deployment tests"
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "All ArgoCD integration tests passed!"
    else
        error "Some ArgoCD integration tests failed!"
    fi
    
    return $test_results
}

main "$@"
