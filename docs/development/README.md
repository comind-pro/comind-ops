# Testing & Validation Framework

Comprehensive testing suite for the Comind-Ops Platform covering infrastructure validation, application testing, and end-to-end scenarios.

## Test Categories

### 1. Unit Tests
- Helm chart template rendering
- Terraform module validation  
- Script function testing
- Configuration validation

### 2. Integration Tests
- Kubernetes manifest application
- ArgoCD ApplicationSet functionality
- Platform service connectivity
- Cross-component integration

### 3. End-to-End Tests
- Complete application deployment
- Multi-environment promotion
- Disaster recovery scenarios
- Security compliance validation

### 4. Performance Tests
- Load testing platform services
- Resource consumption validation
- Scalability testing
- Network performance validation

## Directory Structure

```
tests/
├── unit/                    # Unit tests
│   ├── helm/               # Helm chart unit tests
│   ├── terraform/          # Terraform module tests
│   └── scripts/            # Script unit tests
├── integration/            # Integration tests  
│   ├── kubernetes/         # K8s integration tests
│   ├── argocd/            # ArgoCD integration tests
│   └── platform/          # Platform service tests
├── e2e/                   # End-to-end tests
│   ├── deployment/        # Full deployment tests
│   ├── scenarios/         # Business scenario tests
│   └── security/          # Security validation tests
├── performance/           # Performance tests
│   ├── load/              # Load testing
│   └── stress/            # Stress testing
├── fixtures/              # Test data and fixtures
└── utils/                 # Testing utilities
```

## Running Tests

### Quick Test
```bash
# Run all tests
make test

# Run specific test category
make test-unit
make test-integration
make test-e2e

# Test specific component
make test-helm
make test-terraform
```

### Detailed Testing
```bash
# Run with verbose output
./tests/test-ci.sh all --verbose

# Test specific application
./tests/run-tests.sh --app sample-app --category integration

# Performance testing
./tests/performance/run-load-tests.sh
```

## Test Requirements

### Prerequisites
- Local k3d cluster or access to test cluster
- Required CLI tools (helm, kubectl, terraform)
- Docker for container testing
- Test data and fixtures

### Environment Setup
```bash
# Setup test environment
make test-setup

# Create test cluster
./tests/utils/create-test-cluster.sh

# Install test dependencies
./tests/utils/install-test-deps.sh
```

## Test Reports

Tests generate reports in multiple formats:
- **JUnit XML**: For CI/CD integration
- **HTML Reports**: For human-readable results  
- **JSON**: For programmatic processing
- **Coverage Reports**: Code and infrastructure coverage

Reports are stored in `tests/reports/` and uploaded as CI/CD artifacts.
