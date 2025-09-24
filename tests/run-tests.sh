#!/bin/bash
set -euo pipefail

# Comprehensive test runner for Comind-Ops Platform
# Executes various test suites and generates reports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$SCRIPT_DIR"
REPORTS_DIR="$TESTS_DIR/reports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[TEST]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Default values
CATEGORY="all"
SPECIFIC_APP=""
VERBOSE=false
PARALLEL=false
CLEANUP=true
REPORT_FORMAT="junit"
TEST_TIMEOUT=300

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive test suite for Comind-Ops Platform

Options:
    --category CATEGORY     Test category: unit|integration|e2e|performance|all (default: all)
    --app APP              Test specific application only
    --verbose              Enable verbose output
    --parallel             Run tests in parallel where possible
    --no-cleanup           Skip cleanup after tests
    --format FORMAT        Report format: junit|html|json (default: junit)
    --timeout SECONDS      Test timeout in seconds (default: 300)
    --help                 Show this help message

Categories:
    unit                   Unit tests (Helm, Terraform, Scripts)
    integration            Integration tests (K8s, ArgoCD, Platform)
    e2e                    End-to-end tests (Full scenarios)
    performance            Performance and load tests
    all                    All test categories

Examples:
    $0                                    # Run all tests
    $0 --category unit --verbose          # Run unit tests with verbose output
    $0 --app sample-app --category e2e     # E2E tests for specific app
    $0 --parallel --format html           # Parallel tests with HTML reports
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --app)
            SPECIFIC_APP="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --format)
            REPORT_FORMAT="$2"
            shift 2
            ;;
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
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

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Check dependencies
    local deps=("helm" "kubectl" "terraform")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Required dependency not found: $dep"
            exit 1
        fi
    done
    
    # Set timeouts
    export TIMEOUT="$TEST_TIMEOUT"
    
    success "Test environment ready"
}

# Unit Tests
run_unit_tests() {
    log "Running unit tests..."
    
    local unit_results=0
    
    # Helm unit tests
    log "Running Helm unit tests..."
    if "$TESTS_DIR/unit/helm/test-helm-charts.sh" ${SPECIFIC_APP:+--app "$SPECIFIC_APP"}; then
        success "Helm unit tests passed"
    else
        error "Helm unit tests failed"
        unit_results=1
    fi
    
    # Terraform unit tests
    log "Running Terraform unit tests..."
    if "$TESTS_DIR/unit/terraform/test-terraform-modules.sh"; then
        success "Terraform unit tests passed"
    else
        error "Terraform unit tests failed"
        unit_results=1
    fi
    
    # Script unit tests
    log "Running script unit tests..."
    if "$TESTS_DIR/unit/scripts/test-scripts.sh"; then
        success "Script unit tests passed"
    else
        error "Script unit tests failed"
        unit_results=1
    fi
    
    return $unit_results
}

# Integration Tests
run_integration_tests() {
    log "Running integration tests..."
    
    local integration_results=0
    
    # Kubernetes integration tests
    log "Running Kubernetes integration tests..."
    if "$TESTS_DIR/integration/kubernetes/test-k8s-integration.sh" ${SPECIFIC_APP:+--app "$SPECIFIC_APP"}; then
        success "Kubernetes integration tests passed"
    else
        error "Kubernetes integration tests failed"
        integration_results=1
    fi
    
    # ArgoCD integration tests
    log "Running ArgoCD integration tests..."
    if "$TESTS_DIR/integration/argocd/test-argocd-integration.sh"; then
        success "ArgoCD integration tests passed"
    else
        error "ArgoCD integration tests failed"
        integration_results=1
    fi
    
    # Platform service integration tests
    log "Running platform service integration tests..."
    if "$TESTS_DIR/integration/platform/test-platform-integration.sh"; then
        success "Platform integration tests passed"
    else
        error "Platform integration tests failed"
        integration_results=1
    fi
    
    return $integration_results
}

# End-to-End Tests
run_e2e_tests() {
    log "Running end-to-end tests..."
    
    local e2e_results=0
    
    # Full deployment scenario
    log "Running deployment scenario tests..."
    if "$TESTS_DIR/e2e/deployment/test-full-deployment.sh" ${SPECIFIC_APP:+--app "$SPECIFIC_APP"}; then
        success "Deployment scenario tests passed"
    else
        error "Deployment scenario tests failed"
        e2e_results=1
    fi
    
    # Business scenario tests
    log "Running business scenario tests..."
    if "$TESTS_DIR/e2e/scenarios/test-business-scenarios.sh"; then
        success "Business scenario tests passed"
    else
        error "Business scenario tests failed"
        e2e_results=1
    fi
    
    # Security validation tests
    log "Running security validation tests..."
    if "$TESTS_DIR/e2e/security/test-security-validation.sh"; then
        success "Security validation tests passed"
    else
        error "Security validation tests failed"
        e2e_results=1
    fi
    
    return $e2e_results
}

# Performance Tests
run_performance_tests() {
    log "Running performance tests..."
    
    local perf_results=0
    
    # Load testing
    log "Running load tests..."
    if "$TESTS_DIR/performance/load/test-load.sh" ${SPECIFIC_APP:+--app "$SPECIFIC_APP"}; then
        success "Load tests passed"
    else
        error "Load tests failed"
        perf_results=1
    fi
    
    # Stress testing
    log "Running stress tests..."
    if "$TESTS_DIR/performance/stress/test-stress.sh"; then
        success "Stress tests passed"
    else
        error "Stress tests failed"
        perf_results=1
    fi
    
    return $perf_results
}

# Generate test report
generate_report() {
    local test_results=("$@")
    log "Generating test report..."
    
    local report_file="$REPORTS_DIR/test-report-$(date +%Y%m%d-%H%M%S)"
    
    case "$REPORT_FORMAT" in
        junit)
            generate_junit_report "${test_results[@]}" > "$report_file.xml"
            ;;
        html)
            generate_html_report "${test_results[@]}" > "$report_file.html"
            ;;
        json)
            generate_json_report "${test_results[@]}" > "$report_file.json"
            ;;
    esac
    
    success "Test report generated: $report_file.$REPORT_FORMAT"
}

# Generate JUnit XML report
generate_junit_report() {
    local results=("$@")
    cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="ComindOps Platform Tests" time="$(date)" tests="${#results[@]}">
$(
    for i in "${!results[@]}"; do
        local category=""
        case $i in
            0) category="unit" ;;
            1) category="integration" ;;
            2) category="e2e" ;;
            3) category="performance" ;;
        esac
        
        local status="passed"
        local failure=""
        if [[ "${results[$i]}" != "0" ]]; then
            status="failed"
            failure='<failure message="Test suite failed"/>'
        fi
        
        echo "  <testsuite name=\"$category\" tests=\"1\" failures=\"$([ "${results[$i]}" != "0" ] && echo 1 || echo 0)\">"
        echo "    <testcase name=\"$category-tests\" status=\"$status\">$failure</testcase>"
        echo "  </testsuite>"
    done
)
</testsuites>
EOF
}

# Generate HTML report
generate_html_report() {
    local results=("$@")
    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Comind-Ops Platform Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .summary { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Comind-Ops Platform Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Category: $CATEGORY</p>
        $([ -n "$SPECIFIC_APP" ] && echo "<p>Application: $SPECIFIC_APP</p>")
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <table>
            <tr><th>Test Suite</th><th>Status</th><th>Result</th></tr>
$(
    local categories=("Unit Tests" "Integration Tests" "E2E Tests" "Performance Tests")
    for i in "${!results[@]}"; do
        local status_class="pass"
        local status_text="PASSED"
        if [[ "${results[$i]}" != "0" ]]; then
            status_class="fail"
            status_text="FAILED"
        fi
        echo "            <tr><td>${categories[$i]}</td><td class=\"$status_class\">$status_text</td><td>${results[$i]}</td></tr>"
    done
)
        </table>
    </div>
</body>
</html>
EOF
}

# Generate JSON report
generate_json_report() {
    local results=("$@")
    local categories=("unit" "integration" "e2e" "performance")
    
    cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "category": "$CATEGORY",
    "app": "${SPECIFIC_APP:-"all"}",
    "format": "$REPORT_FORMAT",
    "results": {
$(
    for i in "${!results[@]}"; do
        local comma=""
        [ $i -lt $((${#results[@]} - 1)) ] && comma=","
        echo "        \"${categories[$i]}\": { \"exit_code\": ${results[$i]}, \"status\": \"$([ "${results[$i]}" == "0" ] && echo "passed" || echo "failed")\" }$comma"
    done
)
    },
    "summary": {
        "total": ${#results[@]},
        "passed": $(printf '%s\n' "${results[@]}" | awk '$1 == 0 { count++ } END { print count+0 }'),
        "failed": $(printf '%s\n' "${results[@]}" | awk '$1 != 0 { count++ } END { print count+0 }')
    }
}
EOF
}

# Cleanup function
cleanup_tests() {
    if [[ "$CLEANUP" == "true" ]]; then
        log "Cleaning up test environment..."
        
        # Clean up any test resources
        kubectl delete namespace test-namespace --ignore-not-found=true 2>/dev/null || true
        
        # Clean up temporary files
        rm -rf /tmp/comind-ops-tests-* 2>/dev/null || true
        
        success "Cleanup completed"
    fi
}

# Main test execution
main() {
    log "Starting Comind-Ops Platform test suite..."
    log "Category: $CATEGORY, App: ${SPECIFIC_APP:-all}, Format: $REPORT_FORMAT"
    
    setup_test_environment
    
    # Track test results
    local test_results=()
    local overall_result=0
    
    # Run tests based on category
    case "$CATEGORY" in
        unit)
            run_unit_tests
            test_results=(${?} 0 0 0)
            ;;
        integration)
            run_integration_tests
            test_results=(0 ${?} 0 0)
            ;;
        e2e)
            run_e2e_tests
            test_results=(0 0 ${?} 0)
            ;;
        performance)
            run_performance_tests
            test_results=(0 0 0 ${?})
            ;;
        all)
            log "Running all test categories..."
            
            run_unit_tests
            local unit_result=$?
            
            run_integration_tests
            local integration_result=$?
            
            run_e2e_tests
            local e2e_result=$?
            
            run_performance_tests
            local perf_result=$?
            
            test_results=($unit_result $integration_result $e2e_result $perf_result)
            ;;
        *)
            error "Invalid category: $CATEGORY"
            exit 1
            ;;
    esac
    
    # Calculate overall result
    for result in "${test_results[@]}"; do
        if [[ $result -ne 0 ]]; then
            overall_result=1
        fi
    done
    
    # Generate report
    generate_report "${test_results[@]}"
    
    # Cleanup
    cleanup_tests
    
    # Final results
    echo
    log "Test Results Summary:"
    echo "===================="
    
    local categories=("Unit Tests" "Integration Tests" "E2E Tests" "Performance Tests")
    for i in "${!test_results[@]}"; do
        local status="PASSED ✅"
        if [[ "${test_results[$i]}" != "0" ]]; then
            status="FAILED ❌"
        fi
        echo "${categories[$i]}: $status"
    done
    
    echo
    if [[ $overall_result -eq 0 ]]; then
        success "All tests passed! 🎉"
        log "The Comind-Ops Platform is ready for deployment."
    else
        error "Some tests failed! ❌"
        log "Please review the test results and fix any issues."
    fi
    
    return $overall_result
}

# Run main function
main "$@"
