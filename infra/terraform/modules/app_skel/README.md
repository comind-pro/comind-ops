# App Skeleton Terraform Module

Comprehensive Terraform module for provisioning application-specific infrastructure in the Comind-Ops Platform. Supports both local development (k3d) and cloud deployments (AWS/DigitalOcean) with a consistent interface.

> **Note**: This module integrates with external PostgreSQL and MinIO services running as Docker containers (managed in `infra/docker/`). For local development, these services are automatically configured to work with the infrastructure provisioned by this module.

## Overview

The `app_skel` module provides a complete infrastructure foundation for applications, including:

- **Database**: PostgreSQL with automated backups and monitoring
- **Storage**: S3/MinIO buckets with lifecycle policies
- **Queue**: SQS/ElasticMQ message queues with DLQ support
- **Cache**: Redis/ElastiCache for high-performance caching
- **Networking**: Ingress configuration and DNS management
- **Monitoring**: Prometheus integration with custom metrics
- **Security**: RBAC, network policies, and service accounts
- **Backup**: Automated backup jobs with configurable retention

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP SKELETON MODULE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   DATABASE      │  │    STORAGE      │  │     QUEUE       │  │
│  │                 │  │                 │  │                 │  │
│  │ • PostgreSQL    │  │ • S3/MinIO      │  │ • SQS/ElasticMQ │  │
│  │ • Automated     │  │ • Lifecycle     │  │ • Dead Letter   │  │
│  │   Backups       │  │ • Versioning    │  │   Queues        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │     CACHE       │  │   NETWORKING    │  │   MONITORING    │  │
│  │                 │  │                 │  │                 │  │
│  │ • Redis/        │  │ • Ingress       │  │ • ServiceMonitor│  │
│  │   ElastiCache   │  │ • DNS Records   │  │ • Dashboards    │  │
│  │ • HA Support    │  │ • TLS Certs     │  │ • Alerts        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "my_app" {
  source = "./modules/app_skel"
  
  # Basic configuration
  app_name     = "my-awesome-app"
  environment  = "dev"
  team         = "backend"
  cluster_type = "local"
  
  # Enable basic services
  database = {
    enabled = true
  }
  
  storage = {
    enabled = true
    buckets = [
      {
        name = "uploads"
        versioning_enabled = true
      }
    ]
  }
  
  queue = {
    enabled = true
    queues = [
      {
        name = "default"
      }
    ]
  }
  
  monitoring = {
    enabled = true
  }
  
  tags = {
    Project = "MyProject"
    Owner   = "Backend Team"
  }
}
```

### Production Configuration

```hcl
module "my_app_prod" {
  source = "./modules/app_skel"
  
  app_name     = "my-awesome-app"
  environment  = "prod"
  team         = "backend"
  cluster_type = "aws"
  
  # Production database
  database = {
    enabled                 = true
    instance_class          = "db.r5.xlarge"
    allocated_storage       = 100
    multi_az               = true
    backup_retention_period = 30
    deletion_protection    = true
  }
  
  # Production storage with multiple buckets
  storage = {
    enabled = true
    buckets = [
      {
        name                = "uploads"
        versioning_enabled  = true
        lifecycle_enabled   = true
        lifecycle_expiration = 2555
      },
      {
        name        = "public-assets"
        public_read = true
      }
    ]
  }
  
  # Production queuing
  queue = {
    enabled = true
    queues = [
      {
        name                       = "default"
        visibility_timeout_seconds = 300
        dlq_enabled               = true
      }
    ]
  }
  
  # Production caching
  cache = {
    enabled         = true
    node_type       = "cache.r5.large"
    num_cache_nodes = 3
  }
  
  # Enhanced security
  security = {
    create_iam_role        = true
    namespace_isolation    = true
  }
  
  # Production backups
  backup = {
    enabled                 = true
    retention_days          = 30
    database_backup_enabled = true
    storage_backup_enabled  = true
  }
  
  tags = {
    Environment = "production"
    Project     = "MyProject"
    Owner       = "Backend Team"
  }
}
```

## Module Components

### Database Module
- **Local**: Bitnami PostgreSQL Helm chart
- **AWS**: RDS PostgreSQL with performance insights
- **DigitalOcean**: Managed PostgreSQL cluster
- **Features**: Automated backups, monitoring, HA support

### Storage Module
- **Local**: MinIO with persistent volumes
- **AWS**: S3 with lifecycle policies and IAM
- **DigitalOcean**: Spaces with CDN integration
- **Features**: Versioning, CORS, public access control

### Queue Module  
- **Local**: Platform ElasticMQ (shared service)
- **AWS**: SQS with dead letter queues
- **Features**: Configurable timeouts, DLQ support

### Cache Module
- **Local**: Redis Helm chart
- **AWS**: ElastiCache Redis cluster
- **Features**: Persistence, clustering, monitoring

## Environment-Specific Configurations

### Development
- Single replica deployments
- Smaller resource allocations  
- Debug logging enabled
- Relaxed security policies
- Local storage backends

### Staging
- Production-like setup
- Multi-AZ for testing
- SSL/TLS enabled
- Performance monitoring
- Automated testing hooks

### Production
- High availability setup
- Performance optimized
- Enhanced security
- Comprehensive monitoring
- Cross-region backup

## Resource Management

### Resource Quotas by Environment

| Resource | Dev | Stage | Prod |
|----------|-----|-------|------|
| **CPU Requests** | 1 core | 2 cores | 4 cores |
| **Memory Requests** | 2Gi | 4Gi | 8Gi |
| **CPU Limits** | 2 cores | 4 cores | 8 cores |
| **Memory Limits** | 4Gi | 8Gi | 16Gi |
| **Max Pods** | 10 | 30 | 50 |

## Security Features

### Network Security
- Default deny network policies
- Namespace isolation
- Ingress-only external access
- Platform service communication

### Access Control
- Service account per application
- RBAC with minimal permissions
- IAM roles for cloud resources
- Secret management integration

## Integration Examples

### Using with new-app.sh Script
```bash
# Create new app with infrastructure
./scripts/new-app.sh my-app backend --with-database --with-storage --with-queue

# This generates both Helm chart and Terraform module usage
```

### ArgoCD ApplicationSet Integration
```yaml
# Terraform infrastructure managed by ArgoCD
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: app-infrastructure
spec:
  generators:
  - list:
      elements:
      - app: my-app
        environment: dev
  template:
    metadata:
      name: '{{app}}-{{environment}}-infra'
    spec:
      source:
        repoURL: https://github.com/comind-pro/comind-ops
        path: terraform/apps/{{app}}/{{environment}}
```

## Variables

### Required Variables

- `app_name` - Name of the application (lowercase, alphanumeric + hyphens)
- `environment` - Environment (dev, stage, prod)
- `cluster_type` - Deployment target (local, aws, digitalocean)

### Optional Variables

- `team` - Team responsible (default: "platform")
- `database` - Database configuration object
- `storage` - Storage buckets configuration
- `queue` - Message queue configuration
- `cache` - Redis/ElastiCache configuration
- `networking` - Ingress and DNS configuration
- `monitoring` - Observability configuration
- `security` - RBAC and policies configuration
- `backup` - Automated backup configuration
- `tags` - Resource tags

## Outputs

The module provides comprehensive outputs including:

- Service endpoints and connection strings
- Generated credentials and access keys
- Resource identifiers and ARNs
- Configuration for application integration
- Monitoring and security metadata

## Examples

Complete examples are available showing:

- **Basic Web App**: Simple CRUD application
- **Microservice**: API with queue processing  
- **Data Pipeline**: ETL with storage and monitoring
- **Multi-Environment**: Production/staging/dev configurations

## Troubleshooting

### Common Issues

#### Resource Creation Failures
```bash
# Check provider credentials and permissions
terraform plan -detailed-exitcode
kubectl cluster-info
```

#### Database Connection Issues
```bash
# Verify database endpoint and credentials
kubectl get secrets my-app-secrets -o yaml
kubectl logs deployment/my-app
```

### Debug Commands

```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform apply

# Kubernetes resource inspection
kubectl describe namespace my-app-dev
kubectl get events -n my-app-dev
```

This module provides enterprise-grade infrastructure provisioning with the flexibility to run in any environment while maintaining consistent interfaces and best practices.