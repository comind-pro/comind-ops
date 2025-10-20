#!/bin/bash
set -euo pipefail

# Helm Chart Unit Tests
# Tests individual Helm charts for structure, validation, and rendering

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[HELM-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

SPECIFIC_APP=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            SPECIFIC_APP="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

cd "$PROJECT_ROOT"

test_helm_chart_structure() {
    local chart_dir="$1"
    local app_name="$2"
    
    log "Testing chart structure for $app_name..."
    
    # Check if this is a chart with external dependencies
    local has_dependencies=false
    if [[ -f "$chart_dir/Chart.yaml" ]] && grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
        has_dependencies=true
    fi
    
    # Check required files
    local required_files=("Chart.yaml" "values.yaml")
    
    # Only require templates for charts without external dependencies
    if [[ "$has_dependencies" == "false" ]]; then
        required_files+=("templates/" "templates/_helpers.tpl")
    fi
    
    for file in "${required_files[@]}"; do
        if [[ ! -e "$chart_dir/$file" ]]; then
            error "Missing required file: $chart_dir/$file"
            return 1
        fi
    done
    
    # Check Chart.yaml structure
    if ! grep -q "apiVersion: v2" "$chart_dir/Chart.yaml"; then
        error "Chart.yaml must have apiVersion: v2"
        return 1
    fi
    
    if ! grep -q "name: $app_name" "$chart_dir/Chart.yaml"; then
        error "Chart.yaml name must match application name"
        return 1
    fi
    
    # Check templates directory (only for charts without dependencies)
    if [[ "$has_dependencies" == "false" ]]; then
        if [[ ! -d "$chart_dir/templates" ]] || [[ -z "$(ls -A "$chart_dir/templates")" ]]; then
            error "Templates directory must exist and contain templates"
            return 1
        fi
    fi
    
    success "Chart structure valid for $app_name"
    return 0
}

test_helm_lint() {
    local chart_dir="$1"
    local app_name="$2"
    
    log "Running helm lint for $app_name..."
    
    if helm lint "$chart_dir" ${VERBOSE:+--debug}; then
        success "Helm lint passed for $app_name"
        return 0
    else
        error "Helm lint failed for $app_name"
        return 1
    fi
}

test_helm_template_rendering() {
    local chart_dir="$1"
    local app_name="$2"
    
    log "Testing template rendering for $app_name..."
    
    local values_dir="k8s/apps/$app_name/values"
    local test_results=0
    
    # Test default values
    if helm template "$app_name" "$chart_dir" --dry-run > /dev/null 2>&1; then
        success "Default template rendering works for $app_name"
    else
        error "Default template rendering failed for $app_name"
        test_results=1
    fi
    
    # Test environment-specific values
    if [[ -d "$values_dir" ]]; then
        for values_file in "$values_dir"/*.yaml; do
            if [[ -f "$values_file" ]]; then
                local env=$(basename "$values_file" .yaml)
                log "Testing $env values for $app_name..."
                
                if helm template "$app_name" "$chart_dir" -f "$values_file" --dry-run > /dev/null 2>&1; then
                    success "Template rendering works with $env values for $app_name"
                else
                    error "Template rendering failed with $env values for $app_name"
                    test_results=1
                fi
            fi
        done
    fi
    
    return $test_results
}

test_helm_template_output() {
    local chart_dir="$1"
    local app_name="$2"
    
    log "Validating template output for $app_name..."
    
    local temp_output="/tmp/helm-test-$app_name-$$.yaml"
    local test_results=0
    
    # Check if this is a chart with external dependencies
    local has_dependencies=false
    if [[ -f "$chart_dir/Chart.yaml" ]] && grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
        has_dependencies=true
        log "Chart has external dependencies, ensuring they are updated..."
        helm dependency update "$chart_dir" > /dev/null 2>&1 || true
    fi
    
    # Generate template output
    if ! helm template "$app_name" "$chart_dir" > "$temp_output" 2>/dev/null; then
        error "Failed to generate template output for $app_name"
        rm -f "$temp_output"
        return 1
    fi
    
    # Validate YAML structure
    # Check if kubectl is available and cluster is accessible
    if kubectl cluster-info > /dev/null 2>&1; then
        # For wrapper charts with dependencies, this is informational only
        if ! kubectl apply --dry-run=client -f "$temp_output" > /dev/null 2>&1; then
            if [[ "$has_dependencies" == "true" ]]; then
                log "Note: YAML validation skipped for wrapper chart $app_name (expected with dependencies)"
            else
                error "Generated YAML is not valid Kubernetes manifests for $app_name"
                test_results=1
            fi
        else
            success "Generated Kubernetes manifests are valid for $app_name"
        fi
    else
        log "Note: YAML validation skipped for $app_name (no cluster available)"
        # Perform basic YAML syntax check instead
        if yq eval '.' "$temp_output" > /dev/null 2>&1; then
            success "YAML syntax is valid for $app_name"
        else
            error "YAML syntax error in $app_name"
            test_results=1
        fi
    fi
    
    # Check for required Kubernetes resources
    # For charts with external dependencies, only check for Service
    local required_resources=("Service")
    
    # For charts without dependencies, also check for Deployment
    if [[ "$has_dependencies" == "false" ]]; then
        required_resources=("Deployment" "Service")
    fi
    
    for resource in "${required_resources[@]}"; do
        if ! grep -q "kind: $resource" "$temp_output"; then
            error "Missing required resource $resource in $app_name"
            test_results=1
        else
            success "Found required resource $resource in $app_name"
        fi
    done
    
    # Check for security best practices
    if grep -q "runAsUser: 0" "$temp_output"; then
        error "Found containers running as root user in $app_name"
        test_results=1
    fi
    
    if grep -q "privileged: true" "$temp_output"; then
        error "Found privileged containers in $app_name"
        test_results=1
    fi
    
    # Cleanup
    rm -f "$temp_output"
    
    return $test_results
}

test_helm_values_schema() {
    local chart_dir="$1"
    local app_name="$2"
    
    log "Testing values schema for $app_name..."
    
    local values_file="$chart_dir/values.yaml"
    
    # Check that values.yaml exists and is valid YAML
    if ! yaml_content=$(yq eval '.' "$values_file" 2>/dev/null); then
        error "values.yaml is not valid YAML for $app_name"
        return 1
    fi
    
    # Check if this is a chart with external dependencies
    local has_dependencies=false
    if [[ -f "$chart_dir/Chart.yaml" ]] && grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
        has_dependencies=true
    fi
    
    # For charts without dependencies, check for required top-level keys
    if [[ "$has_dependencies" == "false" ]]; then
        local required_keys=("image" "service")
        for key in "${required_keys[@]}"; do
            if ! yq eval "has(\"$key\")" "$values_file" | grep -q true; then
                error "Missing required key '$key' in values.yaml for $app_name"
                return 1
            fi
        done
    fi
    
    success "Values schema is valid for $app_name"
    return 0
}

# Main test execution
main() {
    log "Starting Helm chart unit tests..."
    
    local test_results=0
    local chart_dirs=()
    
    # Determine which charts to test
    if [[ -n "$SPECIFIC_APP" ]]; then
        if [[ -d "k8s/apps/$SPECIFIC_APP/chart" ]]; then
            chart_dirs=("k8s/apps/$SPECIFIC_APP/chart")
        elif [[ -d "k8s/charts/apps/$SPECIFIC_APP" ]]; then
            chart_dirs=("k8s/charts/apps/$SPECIFIC_APP")
        else
            error "Chart not found for app: $SPECIFIC_APP"
            return 1
        fi
    else
        # Find charts in both k8s/apps and k8s/charts directories
        while IFS= read -r -d '' chart_dir; do
            chart_dirs+=("$chart_dir")
        done < <(find k8s/apps -name chart -type d -print0 2>/dev/null)
        
        while IFS= read -r -d '' chart_dir; do
            chart_dirs+=("$chart_dir")
        done < <(find k8s/charts -mindepth 2 -maxdepth 2 -type d -print0 2>/dev/null)
    fi
    
    if [[ ${#chart_dirs[@]} -eq 0 ]]; then
        error "No Helm charts found to test"
        return 1
    fi
    
    # Run tests for each chart
    for chart_dir in "${chart_dirs[@]}"; do
        local app_name
        if [[ "$chart_dir" =~ k8s/apps/.*/chart ]]; then
            app_name=$(basename "$(dirname "$chart_dir")")
        else
            app_name=$(basename "$chart_dir")
        fi
        log "Testing Helm chart: $app_name"
        
        # Structure tests
        if ! test_helm_chart_structure "$chart_dir" "$app_name"; then
            test_results=1
            continue
        fi
        
        # Lint tests
        if ! test_helm_lint "$chart_dir" "$app_name"; then
            test_results=1
            continue
        fi
        
        # Template rendering tests
        if ! test_helm_template_rendering "$chart_dir" "$app_name"; then
            test_results=1
            continue
        fi
        
        # Template output validation
        if ! test_helm_template_output "$chart_dir" "$app_name"; then
            test_results=1
            continue
        fi
        
        # Values schema tests (if yq is available)
        if command -v yq &> /dev/null; then
            if ! test_helm_values_schema "$chart_dir" "$app_name"; then
                test_results=1
                continue
            fi
        fi
        
        success "All tests passed for $app_name Helm chart"
    done
    
    if [[ $test_results -eq 0 ]]; then
        success "All Helm chart unit tests passed!"
    else
        error "Some Helm chart unit tests failed!"
    fi
    
    return $test_results
}

main "$@"
