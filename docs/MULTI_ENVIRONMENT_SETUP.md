# Multi-Environment Setup Guide

This guide explains how to configure and deploy multiple environments (dev, stage, qa, prod) in a single Kubernetes cluster.

## Overview

The ComindOps Platform supports two deployment modes:

1. **Single Environment**: Deploy only one environment (dev, stage, qa, or prod)
2. **Multi-Environment**: Deploy all environments (dev, stage, qa, prod) in the same cluster

## Environment Configuration

### Environment Variables

Configure your `.env` file with the following variables:

```bash
# Environment name (dev, stage, qa, prod)
ENVIRONMENT=dev

# Enable multiple environments in single cluster
MULTI_ENVIRONMENT=false

# Environment-specific namespace prefixes
NAMESPACE_PREFIX=platform

# Environment-specific domain suffixes
DOMAIN_SUFFIX=127.0.0.1.nip.io
```

### Environment-Specific Settings

Each environment has its own configuration:

```bash
# Development environment
DEV_NAMESPACE=platform-dev
DEV_DOMAIN=dev.127.0.0.1.nip.io
DEV_REPLICAS=1
DEV_RESOURCES_LIMITS_CPU=500m
DEV_RESOURCES_LIMITS_MEMORY=512Mi

# Staging environment
STAGE_NAMESPACE=platform-stage
STAGE_DOMAIN=stage.127.0.0.1.nip.io
STAGE_REPLICAS=2
STAGE_RESOURCES_LIMITS_CPU=1000m
STAGE_RESOURCES_LIMITS_MEMORY=1Gi

# QA environment
QA_NAMESPACE=platform-qa
QA_DOMAIN=qa.127.0.0.1.nip.io
QA_REPLICAS=2
QA_RESOURCES_LIMITS_CPU=1000m
QA_RESOURCES_LIMITS_MEMORY=1Gi

# Production environment
PROD_NAMESPACE=platform-prod
PROD_DOMAIN=prod.127.0.0.1.nip.io
PROD_REPLICAS=3
PROD_RESOURCES_LIMITS_CPU=2000m
PROD_RESOURCES_LIMITS_MEMORY=2Gi
```

## Deployment Modes

### Single Environment Deployment

Deploy only one environment:

```bash
# Setup environment configuration
make setup-env

# Edit .env file
nano .env
# Set: ENVIRONMENT=dev

# Validate and deploy
make validate-env
make bootstrap ENV=dev
```

**Result:**
- Only `platform-dev` namespace is created
- Services deployed to `platform-dev` namespace
- ArgoCD applications target `platform-dev` namespace

### Multi-Environment Deployment

Deploy multiple environments in the same cluster:

```bash
# Setup environment configuration
make setup-env

# Edit .env file
nano .env
# Set: ENVIRONMENT=dev

# Validate and deploy specific environments
make validate-env
make bootstrap ENV=dev,stage

# Or deploy all environments
make bootstrap ENV=dev,stage,qa,prod
```

**Result:**
- Selected namespaces created: `platform-dev`, `platform-stage`, etc.
- Services deployed to each environment namespace
- ArgoCD applications target all specified environment namespaces

## Namespace Structure

### Single Environment
```
platform-dev/
├── redis
├── postgresql
├── minio
└── monitoring-dashboard
```

### Multi-Environment
```
platform-dev/
├── redis
├── postgresql
├── minio
└── monitoring-dashboard

platform-stage/
├── redis
├── postgresql
├── minio
└── monitoring-dashboard

platform-qa/
├── redis
├── postgresql
├── minio
└── monitoring-dashboard

platform-prod/
├── redis
├── postgresql
├── minio
└── monitoring-dashboard
```

## Resource Allocation

### Development Environment
- **Replicas**: 1
- **CPU Limit**: 500m
- **Memory Limit**: 512Mi
- **CPU Request**: 100m
- **Memory Request**: 128Mi

### Staging Environment
- **Replicas**: 2
- **CPU Limit**: 1000m
- **Memory Limit**: 1Gi
- **CPU Request**: 200m
- **Memory Request**: 256Mi

### QA Environment
- **Replicas**: 2
- **CPU Limit**: 1000m
- **Memory Limit**: 1Gi
- **CPU Request**: 200m
- **Memory Request**: 256Mi

### Production Environment
- **Replicas**: 3
- **CPU Limit**: 2000m
- **Memory Limit**: 2Gi
- **CPU Request**: 500m
- **Memory Request**: 512Mi

## Domain Configuration

### Local Development
- **Dev**: `dev.127.0.0.1.nip.io`
- **Stage**: `stage.127.0.0.1.nip.io`
- **QA**: `qa.127.0.0.1.nip.io`
- **Prod**: `prod.127.0.0.1.nip.io`

### AWS Production
- **Dev**: `dev.comind.pro`
- **Stage**: `stage.comind.pro`
- **QA**: `qa.comind.pro`
- **Prod**: `prod.comind.pro`

## ArgoCD Configuration

### Single Environment
ArgoCD project allows access to:
- `platform-dev` namespace
- `*` namespace (for system resources)

### Multi-Environment
ArgoCD project allows access to:
- `platform-dev` namespace
- `platform-stage` namespace
- `platform-qa` namespace
- `platform-prod` namespace
- `*` namespace (for system resources)

## Makefile Commands

### Environment Selection
```bash
# Deploy single environment
make bootstrap ENV=dev
make bootstrap ENV=stage
make bootstrap ENV=qa
make bootstrap ENV=prod

# Deploy multiple environments (comma-separated)
make bootstrap ENV=dev,stage
make bootstrap ENV=dev,stage,qa
make bootstrap ENV=dev,stage,qa,prod
```

### Environment-Specific Operations
```bash
# Deploy to specific environment
make tf-apply-app APP=my-app ENV=dev
make tf-apply-app APP=my-app ENV=stage
make tf-apply-app APP=my-app ENV=qa
make tf-apply-app APP=my-app ENV=prod

# Check status for specific environment
kubectl get pods -n platform-dev
kubectl get pods -n platform-stage
kubectl get pods -n platform-qa
kubectl get pods -n platform-prod
```

## Monitoring and Access

### Single Environment
```bash
# Access monitoring dashboard
make monitoring-access
# Opens: http://monitoring.dev.127.0.0.1.nip.io/
```

### Multi-Environment
```bash
# Access monitoring dashboards
# Dev: http://monitoring.dev.127.0.0.1.nip.io/
# Stage: http://monitoring.stage.127.0.0.1.nip.io/
# QA: http://monitoring.qa.127.0.0.1.nip.io/
# Prod: http://monitoring.prod.127.0.0.1.nip.io/
```

## Best Practices

### 1. Resource Planning
- **Development**: Minimal resources for testing
- **Staging**: Production-like resources for validation
- **QA**: Production-like resources for quality assurance
- **Production**: Maximum resources for reliability

### 2. Environment Isolation
- Each environment has its own namespace
- Separate resource quotas and limits
- Independent scaling policies
- Isolated network policies

### 3. Configuration Management
- Environment-specific Helm values
- Separate secrets per environment
- Environment-specific ingress rules
- Independent monitoring and logging

### 4. Deployment Strategy
- **Development**: Continuous deployment
- **Staging**: Manual deployment for testing
- **QA**: Automated deployment for validation
- **Production**: Manual deployment with approval

## Troubleshooting

### Common Issues

#### 1. Namespace Conflicts
**Error**: `namespace already exists`

**Solution**:
```bash
# Check existing namespaces
kubectl get namespaces | grep platform

# Clean up if needed
kubectl delete namespace platform-dev
kubectl delete namespace platform-stage
kubectl delete namespace platform-qa
kubectl delete namespace platform-prod
```

#### 2. Resource Limits
**Error**: `Insufficient resources`

**Solution**:
```bash
# Check cluster resources
kubectl describe nodes

# Adjust resource limits in .env file
# Reduce replicas or resource requests
```

#### 3. ArgoCD Sync Issues
**Error**: `Application out of sync`

**Solution**:
```bash
# Check ArgoCD applications
argocd app list

# Force sync specific environment
argocd app sync monitoring-dashboard-dev
argocd app sync monitoring-dashboard-stage
argocd app sync monitoring-dashboard-qa
argocd app sync monitoring-dashboard-prod
```

### Debug Commands

```bash
# Check all environment namespaces
kubectl get namespaces | grep platform

# Check pods in all environments
kubectl get pods -A | grep platform

# Check services in all environments
kubectl get services -A | grep platform

# Check ArgoCD applications
argocd app list | grep platform
```

## Migration Guide

### From Single to Multi-Environment

1. **Backup current configuration**:
   ```bash
   cp .env .env.backup
   ```

2. **Deploy multiple environments**:
   ```bash
   # Deploy specific environments
   make bootstrap ENV=dev,stage
   
   # Or deploy all environments
   make bootstrap ENV=dev,stage,qa,prod
   ```

3. **Verify deployment**:
   ```bash
   kubectl get namespaces | grep platform
   kubectl get pods -A | grep platform
   ```

### From Multi to Single Environment

1. **Clean up unused environments**:
   ```bash
   kubectl delete namespace platform-dev
   kubectl delete namespace platform-stage
   kubectl delete namespace platform-qa
   # Keep platform-prod
   ```

2. **Redeploy single environment**:
   ```bash
   make bootstrap ENV=prod
   ```

## Support

For issues with multi-environment setup:

1. Check [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
2. Review [Kubernetes Namespace Documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
3. Check project issues and discussions
4. Contact platform team for assistance
