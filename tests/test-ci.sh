#!/bin/bash
set -euo pipefail

# Test script for CI/CD pipeline validation
# This script can be used to test CI/CD components locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Test CI/CD pipeline components locally

Commands:
    lint            Run linting checks
    helm            Test Helm charts
    terraform       Validate Terraform
    security        Run security scans
    integration     Run integration tests
    all             Run all tests
    help            Show this help message

Options:
    --verbose       Enable verbose output
    --no-docker     Skip tests requiring Docker
    --app APP       Test specific application only

Examples:
    $0 all                    # Run all tests
    $0 lint --verbose         # Run lint checks with verbose output
    $0 helm --app sample-app  # Test specific Helm chart
    $0 terraform              # Validate Terraform configurations
EOF
}

# Parse command line arguments
COMMAND="${1:-help}"
shift || true

VERBOSE=false
NO_DOCKER=false
SPECIFIC_APP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --no-docker)
            NO_DOCKER=true
            shift
            ;;
        --app)
            SPECIFIC_APP="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Set verbose output
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

# Change to project root
cd "$PROJECT_ROOT"

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local deps_ok=true
    
    # Check required tools
    local tools=("helm" "kubectl" "terraform" "yamllint")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is not installed or not in PATH"
            deps_ok=false
        fi
    done
    
    # Check Docker if not skipped
    if [[ "$NO_DOCKER" == "false" ]]; then
        if ! command -v docker &> /dev/null; then
            warning "Docker not available - some tests will be skipped"
            NO_DOCKER=true
        fi
    fi
    
    if [[ "$deps_ok" == "false" ]]; then
        error "Missing required dependencies"
        exit 1
    fi
    
    success "All dependencies available"
}

# Lint checks
run_lint() {
    log "Running linting checks..."
    
    # YAML lint
    log "Running yamllint..."
    if yamllint -c .yamllint.yml .; then
        success "YAML lint passed"
    else
        error "YAML lint failed"
        return 1
    fi
    
    # Shell script lint
    log "Running shellcheck on scripts..."
    local shellcheck_failed=false
    while IFS= read -r -d '' script; do
        if ! shellcheck "$script"; then
            shellcheck_failed=true
        fi
    done < <(find scripts -name "*.sh" -print0)
    
    if [[ "$shellcheck_failed" == "true" ]]; then
        warning "Some shell scripts have issues"
    else
        success "Shell scripts passed validation"
    fi
    
    success "Lint checks completed"
}

# Helm chart testing
run_helm_tests() {
    log "Testing Helm charts..."
    
    local chart_dirs=()
    if [[ -n "$SPECIFIC_APP" ]]; then
        if [[ -d "k8s/apps/$SPECIFIC_APP/chart" ]]; then
            chart_dirs=("k8s/apps/$SPECIFIC_APP/chart")
        else
            error "Chart not found for app: $SPECIFIC_APP"
            return 1
        fi
    else
        while IFS= read -r -d '' chart_dir; do
            chart_dirs+=("$chart_dir")
        done < <(find k8s/apps -name chart -type d -print0)
    fi
    
    for chart_dir in "${chart_dirs[@]}"; do
        local app_name=$(basename "$(dirname "$chart_dir")")
        log "Testing chart: $app_name"
        
        # Helm lint
        if helm lint "$chart_dir"; then
            success "Helm lint passed for $app_name"
        else
            error "Helm lint failed for $app_name"
            return 1
        fi
        
        # Test templates with different values
        local values_dir="k8s/apps/$app_name/values"
        if [[ -d "$values_dir" ]]; then
            for env in dev stage prod; do
                local values_file="$values_dir/$env.yaml"
                if [[ -f "$values_file" ]]; then
                    log "Testing $app_name with $env values..."
                    if helm template "$app_name" "$chart_dir" -f "$values_file" > /dev/null; then
                        success "$app_name template generated for $env"
                    else
                        error "$app_name template failed for $env"
                        return 1
                    fi
                fi
            done
        fi
    done
    
    success "Helm chart tests completed"
}

# Terraform validation
run_terraform_tests() {
    log "Validating Terraform configurations..."
    
    local tf_dirs=(
        "infra/terraform/core"
        "infra/terraform/modules/app_skel"
        "infra/terraform/envs/dev/platform"
    )
    
    for tf_dir in "${tf_dirs[@]}"; do
        if [[ -d "$tf_dir" ]]; then
            log "Validating $tf_dir..."
            
            pushd "$tf_dir" > /dev/null
            
            # Initialize Terraform
            if terraform init -backend=false > /dev/null 2>&1; then
                success "Terraform init successful for $tf_dir"
            else
                error "Terraform init failed for $tf_dir"
                popd > /dev/null
                return 1
            fi
            
            # Validate configuration
            if terraform validate; then
                success "Terraform validate passed for $tf_dir"
            else
                error "Terraform validate failed for $tf_dir"
                popd > /dev/null
                return 1
            fi
            
            # Format check
            if terraform fmt -check -recursive; then
                success "Terraform format check passed for $tf_dir"
            else
                error "Terraform format check failed for $tf_dir"
                popd > /dev/null
                return 1
            fi
            
            popd > /dev/null
        else
            warning "Terraform directory not found: $tf_dir"
        fi
    done
    
    success "Terraform validation completed"
}

# Security scans
run_security_tests() {
    log "Running security scans..."
    
    # Check for common security issues in YAML files
    log "Checking for security anti-patterns..."
    local security_issues=false
    
    # Check for privileged containers
    if grep -r "privileged.*true" k8s/ --include="*.yaml" 2>/dev/null; then
        warning "Found privileged containers"
        security_issues=true
    fi
    
    # Check for root users
    if grep -r "runAsUser.*0" k8s/ --include="*.yaml" 2>/dev/null; then
        warning "Found containers running as root"
        security_issues=true
    fi
    
    # Check for host networking
    if grep -r "hostNetwork.*true" k8s/ --include="*.yaml" 2>/dev/null; then
        warning "Found host networking usage"
        security_issues=true
    fi
    
    if [[ "$security_issues" == "false" ]]; then
        success "No obvious security issues found"
    fi
    
    # Check for secrets in plain text (basic check)
    log "Checking for potential secrets in files..."
    if grep -r -i "password\|secret\|token\|key.*=" --include="*.yaml" --include="*.yml" --exclude-dir=.git . | grep -v "sealed-secrets" | grep -v "#" | head -5; then
        warning "Found potential secrets - please review"
    else
        success "No obvious secrets found in configuration files"
    fi
    
    success "Security scans completed"
}

# Integration tests
run_integration_tests() {
    log "Running integration tests..."
    
    # Test Makefile targets
    log "Testing Makefile targets..."
    if make help > /dev/null; then
        success "Makefile help target works"
    else
        error "Makefile help target failed"
        return 1
    fi
    
    # Test scripts
    log "Testing scripts..."
    local scripts=("new-app.sh" "seal-secret.sh" "tf.sh")
    for script in "${scripts[@]}"; do
        if [[ -x "scripts/$script" ]]; then
            if "./scripts/$script" --help > /dev/null 2>&1; then
                success "Script $script is executable and has help"
            else
                warning "Script $script help might not work properly"
            fi
        else
            error "Script $script is not executable"
            return 1
        fi
    done
    
    # Test Kustomize builds
    log "Testing Kustomize builds..."
    if kubectl kustomize k8s/base/ > /dev/null; then
        success "Base kustomization builds successfully"
    else
        error "Base kustomization failed"
        return 1
    fi
    
    if kubectl kustomize k8s/platform/ > /dev/null; then
        success "Platform kustomization builds successfully"
    else
        error "Platform kustomization failed"
        return 1
    fi
    
    success "Integration tests completed"
}

# Run all tests
run_all_tests() {
    log "Running all CI/CD tests..."
    
    check_dependencies
    
    local failed_tests=()
    
    # Run each test suite
    if ! run_lint; then
        failed_tests+=("lint")
    fi
    
    if ! run_helm_tests; then
        failed_tests+=("helm")
    fi
    
    if ! run_terraform_tests; then
        failed_tests+=("terraform")
    fi
    
    if ! run_security_tests; then
        failed_tests+=("security")
    fi
    
    if ! run_integration_tests; then
        failed_tests+=("integration")
    fi
    
    # Report results
    echo
    log "Test Results Summary:"
    echo "===================="
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        success "All tests passed! ✅"
        echo
        log "The CI/CD pipeline components are working correctly."
        log "You can now commit your changes with confidence."
    else
        error "Some tests failed: ${failed_tests[*]} ❌"
        echo
        log "Please fix the failing tests before committing."
        return 1
    fi
}

# Main execution
case "$COMMAND" in
    lint)
        check_dependencies
        run_lint
        ;;
    helm)
        check_dependencies
        run_helm_tests
        ;;
    terraform)
        check_dependencies
        run_terraform_tests
        ;;
    security)
        check_dependencies
        run_security_tests
        ;;
    integration)
        check_dependencies
        run_integration_tests
        ;;
    all)
        run_all_tests
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
