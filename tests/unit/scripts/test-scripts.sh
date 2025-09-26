#!/bin/bash
set -euo pipefail

# Script Unit Tests
# Tests automation scripts for functionality and reliability

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[SCRIPT-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

cd "$PROJECT_ROOT"

test_script_structure() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing script structure for $script_name..."
    
    # Check if script exists and is executable
    if [[ ! -f "$script_path" ]]; then
        error "Script not found: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        error "Script not executable: $script_path"
        return 1
    fi
    
    # Check shebang
    local shebang=$(head -n1 "$script_path")
    if [[ ! "$shebang" =~ ^#!/bin/bash ]]; then
        error "Invalid or missing shebang in $script_name"
        return 1
    fi
    
    # Check for set -euo pipefail
    if ! grep -q "set -euo pipefail" "$script_path"; then
        error "Missing 'set -euo pipefail' in $script_name"
        return 1
    fi
    
    success "Script structure valid for $script_name"
    return 0
}

test_script_help() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing help functionality for $script_name..."
    
    # Test --help option
    if "$script_path" --help > /dev/null 2>&1; then
        success "Help option works for $script_name"
        return 0
    else
        error "Help option failed for $script_name"
        return 1
    fi
}

test_script_validation() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing input validation for $script_name..."
    
    local test_results=0
    
    # Test with no arguments (should show usage or help)
    if "$script_path" 2>&1 | grep -q -i "usage\|help\|example"; then
        success "Script shows usage when run without arguments: $script_name"
    else
        error "Script doesn't show usage when run without arguments: $script_name"
        test_results=1
    fi
    
    # Test with invalid arguments (if script supports validation)
    case "$script_name" in
        "new-app.sh")
            # Test invalid app name
            if "$script_path" "INVALID-APP-NAME" 2>&1 | grep -q -i "error\|invalid"; then
                success "Input validation works for $script_name"
            else
                log "Input validation test not applicable for $script_name"
            fi
            ;;
        "seal-secret.sh")
            # Test with insufficient arguments
            if "$script_path" 2>&1 | grep -q -i "usage\|required"; then
                success "Argument validation works for $script_name"
            else
                log "Argument validation test not applicable for $script_name"
            fi
            ;;
    esac
    
    return $test_results
}

test_script_functions() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing script functions for $script_name..."
    
    # Check for common good practices
    local test_results=0
    
    # Check for usage function
    if grep -q "print_usage\|show_help\|usage()" "$script_path"; then
        success "Usage function found in $script_name"
    else
        error "No usage function found in $script_name"
        test_results=1
    fi
    
    # Check for logging functions
    if grep -q "log()\|success()\|error()" "$script_path"; then
        success "Logging functions found in $script_name"
    else
        error "No logging functions found in $script_name"
        test_results=1
    fi
    
    # Check for variable validation
    if grep -q "^\s*if.*-z.*then" "$script_path"; then
        success "Variable validation found in $script_name"
    else
        log "No explicit variable validation found in $script_name"
    fi
    
    return $test_results
}

test_script_security() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing script security for $script_name..."
    
    local test_results=0
    
    # Check for hardcoded secrets
    if grep -i "password\|secret\|token" "$script_path" | grep -v "var\|read\|\$" | grep -v "#"; then
        error "Potential hardcoded secrets in $script_name"
        test_results=1
    fi
    
    # Check for unsafe eval or exec
    if grep -E "(^|[^#]).*\b(eval|exec)\b" "$script_path" | grep -v "#"; then
        error "Unsafe eval/exec usage in $script_name"
        test_results=1
    fi
    
    # Check for unsafe temp file usage
    if grep ">/tmp/" "$script_path" | grep -v "\$\$" | grep -v "mktemp"; then
        error "Unsafe temp file usage in $script_name"
        test_results=1
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "Security check passed for $script_name"
    fi
    
    return $test_results
}

test_script_error_handling() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing error handling for $script_name..."
    
    local test_results=0
    
    # Check for error handling patterns
    if grep -q "exit 1\|return 1" "$script_path"; then
        success "Error exit patterns found in $script_name"
    else
        error "No error exit patterns found in $script_name"
        test_results=1
    fi
    
    # Check for cleanup on exit (if applicable)
    if grep -q "trap.*EXIT" "$script_path"; then
        success "Cleanup trap found in $script_name"
    else
        log "No cleanup trap found in $script_name (may not be needed)"
    fi
    
    return $test_results
}

test_makefile_targets() {
    log "Testing Makefile targets..."
    
    local test_results=0
    local makefile="Makefile"
    
    if [[ ! -f "$makefile" ]]; then
        error "Makefile not found"
        return 1
    fi
    
    # Check for required targets
    local required_targets=("help" "bootstrap" "new-app" "clean")
    for target in "${required_targets[@]}"; do
        if grep -q "^$target:" "$makefile"; then
            success "Required target '$target' found in Makefile"
        else
            error "Required target '$target' not found in Makefile"
            test_results=1
        fi
    done
    
    # Check for target descriptions
    if grep -q "##" "$makefile"; then
        success "Target descriptions found in Makefile"
    else
        error "No target descriptions found in Makefile"
        test_results=1
    fi
    
    # Test help target
    if make help > /dev/null 2>&1; then
        success "Makefile help target works"
    else
        error "Makefile help target failed"
        test_results=1
    fi
    
    return $test_results
}

test_script_performance() {
    local script_path="$1"
    local script_name="$2"
    
    log "Testing script performance for $script_name..."
    
    # Simple performance test - help should complete quickly
    local start_time=$(date +%s)
    
    if timeout 10s "$script_path" --help > /dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -lt 5 ]]; then
            success "Script performance acceptable for $script_name ($duration seconds)"
            return 0
        else
            error "Script too slow for $script_name ($duration seconds)"
            return 1
        fi
    else
        error "Script timeout or failure in performance test for $script_name"
        return 1
    fi
}

# Main test execution
main() {
    log "Starting script unit tests..."
    
    local test_results=0
    
    # Define scripts to test
    local scripts=(
        "scripts/new-app.sh:new-app.sh"
        "scripts/seal-secret.sh:seal-secret.sh"
        "infra/terraform/scripts/tf.sh:tf.sh"
        "tests/test-ci.sh:test-ci.sh"
        "tests/run-tests.sh:run-tests.sh"
    )
    
    # Test each script
    for script_entry in "${scripts[@]}"; do
        local script_path="${script_entry%%:*}"
        local script_name="${script_entry##*:}"
        
        if [[ ! -f "$script_path" ]]; then
            error "Script not found: $script_path"
            test_results=1
            continue
        fi
        
        log "Testing script: $script_name"
        
        # Structure tests
        if ! test_script_structure "$script_path" "$script_name"; then
            test_results=1
            continue
        fi
        
        # Help functionality tests
        if ! test_script_help "$script_path" "$script_name"; then
            test_results=1
        fi
        
        # Validation tests
        if ! test_script_validation "$script_path" "$script_name"; then
            test_results=1
        fi
        
        # Function tests
        if ! test_script_functions "$script_path" "$script_name"; then
            test_results=1
        fi
        
        # Security tests
        if ! test_script_security "$script_path" "$script_name"; then
            test_results=1
        fi
        
        # Error handling tests
        if ! test_script_error_handling "$script_path" "$script_name"; then
            test_results=1
        fi
        
        # Performance tests
        if ! test_script_performance "$script_path" "$script_name"; then
            test_results=1
        fi
        
        success "Completed testing $script_name"
    done
    
    # Test Makefile
    if ! test_makefile_targets; then
        test_results=1
    fi
    
    if [[ $test_results -eq 0 ]]; then
        success "All script unit tests passed!"
    else
        error "Some script unit tests failed!"
    fi
    
    return $test_results
}

main "$@"
