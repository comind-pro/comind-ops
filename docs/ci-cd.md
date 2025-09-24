# CI/CD Pipeline Documentation

Comprehensive guide to the Continuous Integration and Continuous Deployment pipelines for the Comind-Ops Platform.

## Overview

The Comind-Ops Platform uses GitHub Actions for CI/CD with multiple specialized workflows designed for infrastructure, security, and application deployment automation.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   TRIGGER    │    │  VALIDATION  │    │  DEPLOYMENT  │              │
│  │              │    │              │    │              │              │
│  │ • Push       │───▶│ • Lint       │───▶│ • Dev        │              │
│  │ • PR         │    │ • Test       │    │ • Staging    │              │
│  │ • Schedule   │    │ • Security   │    │ • Production │              │
│  │ • Manual     │    │ • Build      │    │ • Rollback   │              │
│  └──────────────┘    └──────────────┘    └──────────────┘              │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                        WORKFLOW TYPES                               │ │
│  │                                                                     │ │
│  │ CI: Code validation, testing, security scanning                     │ │
│  │ CD: Build, deploy, and promote across environments                  │ │
│  │ Terraform: Infrastructure provisioning and management               │ │
│  │ Security: Comprehensive security scanning and compliance            │ │
│  │ Helm: Chart validation, testing, and deployment                     │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`

**Jobs:**
- **Lint**: YAML, Helm, shell script validation
- **Terraform**: Multi-directory validation and formatting
- **Kubernetes**: Manifest validation and Kustomize testing
- **Applications**: Helm chart testing across environments
- **Security**: Secret scanning, vulnerability detection
- **Integration**: Quick integration tests

```yaml
name: "CI - Validation and Testing"
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
```

### 2. CD Workflow (`.github/workflows/cd.yml`)

**Triggers:**
- Push to `main` (auto-deploy to dev)
- Git tags starting with `v*` (release deployments)
- Manual workflow dispatch

**Jobs:**
- **Build**: Container image building and registry push
- **Deploy Dev**: Automatic deployment to development
- **Deploy Staging**: Tag-triggered staging deployment
- **Deploy Production**: Manual approval required
- **Infrastructure**: Terraform infrastructure updates
- **Post-Deploy**: Metrics, notifications, release notes

```yaml
name: "CD - Build and Deploy"
on:
  push:
    branches: [ main ]
  tags: [ 'v*' ]
  workflow_dispatch:
```

### 3. Terraform Workflow (`.github/workflows/terraform.yml`)

**Triggers:**
- Changes to `infra/terraform/**`
- Manual workflow dispatch with action selection
- Scheduled drift detection

**Jobs:**
- **Plan**: Generate and review Terraform plans
- **Apply**: Execute infrastructure changes
- **Destroy**: Controlled infrastructure teardown
- **Security**: Infrastructure security scanning
- **Drift**: Detect configuration drift

```yaml
name: "Terraform - Infrastructure Management"
on:
  push:
    paths: ['infra/terraform/**']
  workflow_dispatch:
    inputs:
      action: [plan, apply, destroy]
```

### 4. Security Workflow (`.github/workflows/security.yml`)

**Triggers:**
- Push to `main`
- Pull requests
- Daily scheduled scans at 2 AM UTC
- Manual workflow dispatch

**Jobs:**
- **Secrets**: TruffleHog and GitLeaks secret scanning
- **Vulnerabilities**: Trivy filesystem and container scanning
- **Code Quality**: Semgrep security analysis
- **Infrastructure**: Checkov and tfsec Terraform scanning
- **Dependencies**: GitHub dependency review
- **Compliance**: Policy validation and compliance checking

### 5. Helm Testing Workflow (`.github/workflows/helm-test.yml`)

**Triggers:**
- Changes to `k8s/apps/**/chart/**` or `k8s/apps/**/values/**`
- Pull requests affecting charts

**Jobs:**
- **Changes**: Detect modified charts
- **Lint**: Chart structure and syntax validation
- **Install**: Real cluster installation testing
- **Security**: Chart security policy validation
- **Documentation**: Chart documentation validation

## Environment Strategy

### Development Environment
- **Trigger**: Every push to `main` branch
- **Target**: Local k3d cluster or development cloud environment
- **Approval**: None required (automatic)
- **Features**: Debug logging, relaxed security, fast deployment

### Staging Environment
- **Trigger**: Git tags or manual deployment
- **Target**: Production-like cloud environment
- **Approval**: Automatic after successful dev deployment
- **Features**: Production configuration, comprehensive testing

### Production Environment
- **Trigger**: Git tags with semantic versioning
- **Target**: Production cloud environment
- **Approval**: Manual approval required
- **Features**: Blue/green deployment, comprehensive monitoring

## Security Integration

### Secret Management
- **Detection**: TruffleHog and GitLeaks for committed secrets
- **Prevention**: Pre-commit hooks and PR validation
- **Rotation**: Automated secret rotation workflows
- **Storage**: GitHub Secrets and sealed-secrets integration

### Vulnerability Scanning
- **Code**: Semgrep for code security issues
- **Dependencies**: GitHub Dependabot and security advisories
- **Containers**: Trivy for image vulnerability scanning
- **Infrastructure**: Checkov for IaC security validation

### Compliance
- **Policy Enforcement**: Open Policy Agent (OPA) validation
- **Security Standards**: SOC 2, GDPR, HIPAA compliance checks
- **Audit Logging**: Comprehensive audit trail for all changes
- **Access Control**: RBAC and approval workflows

## Monitoring and Observability

### Pipeline Metrics
- **Build Success Rate**: Percentage of successful builds
- **Deployment Frequency**: How often deployments occur
- **Lead Time**: Time from commit to production
- **Mean Time to Recovery**: Recovery time from failures

### Alerting
- **Failed Builds**: Immediate notification on build failures
- **Security Issues**: Critical security findings alerts
- **Deployment Status**: Success/failure deployment notifications
- **Infrastructure Changes**: Terraform apply notifications

### Dashboards
- **GitHub Actions**: Built-in workflow run visibility
- **Security Dashboard**: Centralized security findings
- **Infrastructure Status**: Terraform state and drift monitoring
- **Application Health**: Post-deployment health validation

## Best Practices

### Code Quality
- **Pre-commit Hooks**: Run linting and basic validation locally
- **Pull Request Validation**: Comprehensive CI on all PRs
- **Branch Protection**: Require CI success before merge
- **Code Reviews**: Mandatory peer review for all changes

### Security
- **Shift Left**: Security validation early in development
- **Least Privilege**: Minimal required permissions
- **Secret Rotation**: Regular credential updates
- **Vulnerability Management**: Prompt patching of issues

### Deployment
- **Blue/Green Deployments**: Zero-downtime production deployments
- **Canary Releases**: Gradual rollout of changes
- **Rollback Plans**: Quick rollback on deployment issues
- **Health Checks**: Comprehensive post-deployment validation

### Infrastructure
- **Infrastructure as Code**: All infrastructure changes via Terraform
- **State Management**: Centralized Terraform state storage
- **Drift Detection**: Regular configuration drift monitoring
- **Environment Parity**: Consistent environments across stages

## Usage Examples

### Deploying a New Application

1. **Create Application**:
   ```bash
   make new-app-full APP=my-service TEAM=backend
   ```

2. **Provision Infrastructure**:
   ```bash
   cd infra/terraform/apps/my-service
   terraform init
   terraform apply
   ```

3. **Deploy via CI/CD**:
   - Push changes to feature branch
   - Create pull request
   - CI validates changes
   - Merge to main triggers dev deployment
   - Tag for staging/production deployment

### Manual Deployment

```bash
# Trigger manual deployment via GitHub CLI
gh workflow run cd.yml \
  -f environment=stage \
  -f force_deploy=true
```

### Infrastructure Changes

```bash
# Trigger Terraform workflow
gh workflow run terraform.yml \
  -f action=plan \
  -f environment=prod \
  -f module=core
```

### Security Scan

```bash
# Trigger security scan
gh workflow run security.yml
```

## Troubleshooting

### Common Issues

#### Failed CI Checks
- **YAML Lint Errors**: Fix indentation and syntax issues
- **Terraform Validation**: Ensure all required providers are configured
- **Helm Lint Failures**: Check chart structure and values files
- **Security Scan Failures**: Address flagged security issues

#### Deployment Failures
- **Image Build Issues**: Check Dockerfile syntax and dependencies
- **Kubernetes Deployment**: Verify manifests and resource availability
- **Health Check Failures**: Ensure application health endpoints work
- **Resource Limits**: Check if resource quotas are exceeded

#### Infrastructure Issues
- **Terraform Apply Failures**: Check permissions and resource limits
- **State Lock Issues**: Release Terraform state locks if stuck
- **Provider Errors**: Verify cloud provider credentials and quotas
- **Drift Detection**: Review and reconcile configuration drift

### Debug Commands

#### GitHub Actions
```bash
# List workflow runs
gh run list --workflow=ci.yml

# View run details
gh run view <run-id>

# Download run artifacts
gh run download <run-id>
```

#### Local Testing
```bash
# Test CI locally with act
act -j lint

# Test Terraform locally
make tf-plan-app APP=my-service

# Test Helm charts
make helm-lint APP=my-service
```

#### Pipeline Status
```bash
# Check overall platform status
make status

# View ArgoCD applications
kubectl get applications -n argocd

# Check deployment status
kubectl get deployments -A
```

## Advanced Configuration

### Custom Workflows

Create custom workflows in `.github/workflows/` for specific needs:

```yaml
name: "Custom Workflow"
on:
  workflow_dispatch:
    inputs:
      custom_param:
        description: 'Custom parameter'
        required: true

jobs:
  custom-job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: "Custom Action"
        run: echo "Custom workflow with ${{ github.event.inputs.custom_param }}"
```

### Environment-Specific Configuration

Use GitHub Environments for different deployment targets:

```yaml
environment:
  name: production
  url: https://my-app.example.com
```

### Conditional Workflows

Run workflows based on specific conditions:

```yaml
if: contains(github.event.head_commit.message, '[skip ci]') == false
```

This CI/CD pipeline provides enterprise-grade automation with security, reliability, and scalability built-in from the start.
