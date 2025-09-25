#!/bin/bash
set -euo pipefail

# Terraform Module Unit Tests
# Tests Terraform modules for structure, validation, and syntax

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log() { echo "[TF-TEST] $1"; }
success() { echo "[PASS] $1"; }
error() { echo "[FAIL] $1" >&2; }

cd "$PROJECT_ROOT"

test_terraform_structure() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform structure for $module_name..."
    
    # Check required files
    local required_files=("main.tf")
    local recommended_files=("variables.tf" "outputs.tf")
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$tf_dir/$file" ]]; then
            error "Missing required file: $tf_dir/$file"
            return 1
        fi
    done
    
    for file in "${recommended_files[@]}"; do
        if [[ ! -f "$tf_dir/$file" ]]; then
            log "Recommended file missing: $tf_dir/$file"
        fi
    done
    
    success "Terraform structure valid for $module_name"
    return 0
}

test_terraform_syntax() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform syntax for $module_name..."
    
    pushd "$tf_dir" > /dev/null
    
    # Initialize Terraform (backend=false for testing)
    if ! terraform init -backend=false > /dev/null 2>&1; then
        error "Terraform init failed for $module_name"
        popd > /dev/null
        return 1
    fi
    
    # Validate syntax
    if ! terraform validate > /dev/null 2>&1; then
        error "Terraform validate failed for $module_name"
        popd > /dev/null
        return 1
    fi
    
    popd > /dev/null
    success "Terraform syntax valid for $module_name"
    return 0
}

test_terraform_format() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform formatting for $module_name..."
    
    pushd "$tf_dir" > /dev/null
    
    # Check formatting
    if ! terraform fmt -check -diff > /dev/null 2>&1; then
        error "Terraform formatting issues found in $module_name"
        popd > /dev/null
        return 1
    fi
    
    popd > /dev/null
    success "Terraform formatting correct for $module_name"
    return 0
}

test_terraform_variables() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform variables for $module_name..."
    
    local variables_file="$tf_dir/variables.tf"
    if [[ ! -f "$variables_file" ]]; then
        log "No variables.tf found for $module_name - skipping variable tests"
        return 0
    fi
    
    # Check for required variable attributes
    local test_results=0
    
    # Extract variable blocks and check for descriptions
    if grep -A 10 "^variable" "$variables_file" | grep -q "description"; then
        success "Variables have descriptions in $module_name"
    else
        error "Some variables lack descriptions in $module_name"
        test_results=1
    fi
    
    # Check for type definitions
    if grep -A 10 "^variable" "$variables_file" | grep -q "type"; then
        success "Variables have type definitions in $module_name"
    else
        error "Some variables lack type definitions in $module_name"
        test_results=1
    fi
    
    return $test_results
}

test_terraform_outputs() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform outputs for $module_name..."
    
    local outputs_file="$tf_dir/outputs.tf"
    if [[ ! -f "$outputs_file" ]]; then
        log "No outputs.tf found for $module_name - skipping output tests"
        return 0
    fi
    
    # Check for output descriptions
    if grep -A 5 "^output" "$outputs_file" | grep -q "description"; then
        success "Outputs have descriptions in $module_name"
        return 0
    else
        error "Some outputs lack descriptions in $module_name"
        return 1
    fi
}

test_terraform_providers() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform providers for $module_name..."
    
    local test_results=0
    
    # Check for terraform block
    if ! grep -q "terraform {" "$tf_dir"/*.tf 2>/dev/null; then
        error "Missing terraform configuration block in $module_name"
        test_results=1
    fi
    
    # Check for required_providers
    if grep -A 20 "terraform {" "$tf_dir"/*.tf 2>/dev/null | grep -q "required_providers"; then
        success "Required providers defined in $module_name"
    else
        error "Missing required_providers in $module_name"
        test_results=1
    fi
    
    # Check for version constraints
    if grep -A 20 "required_providers" "$tf_dir"/*.tf 2>/dev/null | grep -q "version"; then
        success "Provider version constraints defined in $module_name"
    else
        error "Missing provider version constraints in $module_name"
        test_results=1
    fi
    
    return $test_results
}

test_terraform_security() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform security practices for $module_name..."
    
    local test_results=0
    
    # Check for hardcoded secrets
    if grep -r -i "password\|secret\|token" "$tf_dir"/*.tf 2>/dev/null | grep -v "var\." | grep -v "random_password" | grep -v "#"; then
        error "Potential hardcoded secrets found in $module_name"
        test_results=1
    fi
    
    # Check for proper resource naming
    if grep -r "resource \"" "$tf_dir"/*.tf 2>/dev/null | grep -q '""'; then
        error "Resources with empty names found in $module_name"
        test_results=1
    fi
    
    # Check for sensitive outputs
    local sensitive_keywords=("password" "secret" "token" "key")
    for keyword in "${sensitive_keywords[@]}"; do
        if grep -A 5 "output.*$keyword" "$tf_dir"/*.tf 2>/dev/null | grep -q "sensitive.*true"; then
            success "Sensitive output properly marked in $module_name"
        elif grep -q "output.*$keyword" "$tf_dir"/*.tf 2>/dev/null; then
            error "Potentially sensitive output not marked as sensitive in $module_name"
            test_results=1
        fi
    done
    
    return $test_results
}

test_terraform_documentation() {
    local tf_dir="$1"
    local module_name="$2"
    
    log "Testing Terraform documentation for $module_name..."
    
    local readme_file="$tf_dir/README.md"
    local test_results=0
    
    if [[ ! -f "$readme_file" ]]; then
        error "Missing README.md in $module_name"
        return 1
    fi
    
    # Check for required documentation sections
    local required_sections=("Usage" "Variables" "Outputs")
    for section in "${required_sections[@]}"; do
        if ! grep -q "## $section\|# $section" "$readme_file"; then
            error "Missing $section section in README for $module_name"
            test_results=1
        fi
    done
    
    if [[ $test_results -eq 0 ]]; then
        success "Documentation complete for $module_name"
    fi
    
    return $test_results
}

# Main test execution
main() {
    log "Starting Terraform module unit tests..."
    
    local test_results=0
    
    # Define Terraform directories to test
    local tf_directories=(
        "infra/terraform/core:Core Infrastructure"
        "infra/terraform/modules/app_skel:App Skeleton Module"
        "infra/terraform/envs/dev/platform:Platform Environment"
    )
    
    # Test each Terraform directory
    for tf_entry in "${tf_directories[@]}"; do
        local tf_dir="${tf_entry%%:*}"
        local module_name="${tf_entry##*:}"
        
        if [[ ! -d "$tf_dir" ]]; then
            error "Terraform directory not found: $tf_dir"
            test_results=1
            continue
        fi
        
        log "Testing Terraform module: $module_name"
        
        # Structure tests
        if ! test_terraform_structure "$tf_dir" "$module_name"; then
            test_results=1
            continue
        fi
        
        # Syntax tests
        if ! test_terraform_syntax "$tf_dir" "$module_name"; then
            test_results=1
            continue
        fi
        
        # Format tests
        if ! test_terraform_format "$tf_dir" "$module_name"; then
            test_results=1
            continue
        fi
        
        # Variables tests
        if ! test_terraform_variables "$tf_dir" "$module_name"; then
            test_results=1
        fi
        
        # Outputs tests
        if ! test_terraform_outputs "$tf_dir" "$module_name"; then
            test_results=1
        fi
        
        # Providers tests
        if ! test_terraform_providers "$tf_dir" "$module_name"; then
            test_results=1
        fi
        
        # Security tests
        if ! test_terraform_security "$tf_dir" "$module_name"; then
            test_results=1
        fi
        
        # Documentation tests
        if ! test_terraform_documentation "$tf_dir" "$module_name"; then
            test_results=1
        fi
        
        if [[ $test_results -eq 0 ]]; then
            success "All tests passed for $module_name"
        fi
    done
    
    if [[ $test_results -eq 0 ]]; then
        success "All Terraform module unit tests passed!"
    else
        error "Some Terraform module unit tests failed!"
    fi
    
    return $test_results
}

main "$@"
