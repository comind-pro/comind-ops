# Comind-Ops Platform Infrastructure Flow

## Overview

This document describes the complete infrastructure flow for the Comind-Ops Platform, from initial setup to full application deployment.

## Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. TERRAFORM (Infrastructure Foundation)                      │
│     ├── Cluster Management (k3d/EKS)                          │
│     ├── Kubernetes Version & Configuration                     │
│     ├── ArgoCD Installation & Configuration                    │
│     ├── External Services (Local Only)                         │
│     └── Initial Platform Setup                                 │
│                                                                 │
│  2. DOCKER SERVICES (External Dependencies)                    │
│     ├── PostgreSQL (Database)                                  │
│     ├── MinIO (Object Storage)                                 │
│     ├── Redis (Cache) - Optional                               │
│     └── ElasticMQ (Message Queue) - Optional                   │
│                                                                 │
│  3. ARGOCD (GitOps Platform)                                   │
│     ├── Platform Services Deployment                           │
│     ├── Application Infrastructure                              │
│     ├── Continuous Deployment                                  │
│     └── Configuration Management                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Flow

### Phase 1: Terraform Infrastructure Setup

**Responsibility**: Core infrastructure, Kubernetes, ArgoCD, and initial platform configuration

#### Local Environment (`PROFILE=local`)
```bash
make bootstrap PROFILE=local
```

**Terraform manages**:
1. **K3d Cluster Creation**
   - Creates local Kubernetes cluster
   - Configures kubeconfig
   - Sets up cluster networking

2. **Kubernetes Infrastructure**
   - Creates namespaces (platform-dev, argocd, sealed-secrets, etc.)
   - Installs MetalLB for load balancing
   - Installs Nginx Ingress Controller
   - Installs Sealed Secrets for secret management

3. **ArgoCD Installation**
   - Installs ArgoCD via Helm
   - Configures GitOps repository access
   - Sets up ArgoCD projects and RBAC
   - Configures ingress for ArgoCD UI

4. **External Services Validation**
   - Checks Docker services status
   - Validates service health
   - Provides status reporting

#### AWS Environment (`PROFILE=aws`)
```bash
make bootstrap PROFILE=aws
```

**Terraform manages**:
1. **AWS Infrastructure**
   - VPC, subnets, internet gateway, NAT gateway
   - Security groups and route tables
   - EKS cluster creation and configuration

2. **EKS Cluster**
   - Creates EKS cluster with specified Kubernetes version
   - Configures node groups
   - Sets up cluster networking and security

3. **ArgoCD Installation**
   - Installs ArgoCD via Helm
   - Configures for AWS LoadBalancer
   - Sets up GitOps repository access

### Phase 2: Docker External Services (Local Only)

**Responsibility**: External dependencies that run outside Kubernetes

#### Required Services
```bash
make services-setup
```

**Docker Services**:
1. **PostgreSQL** (`comind-ops-postgres`)
   - Database for applications
   - Port: 5432
   - Database: `comind_ops_dev`
   - Username: `postgres`
   - Password: `postgres`

2. **MinIO** (`comind-ops-minio`)
   - S3-compatible object storage
   - Port: 9000 (API), 9001 (Console)
   - Access Key: `minioadmin`
   - Secret Key: `minioadmin`

#### Optional Services
3. **Redis** (`comind-ops-redis`)
   - Caching service
   - Port: 6379
   - No authentication (local dev)

4. **ElasticMQ** (`comind-ops-elasticmq`)
   - SQS-compatible message queue
   - Port: 9324 (HTTP), 9325 (HTTPS)

### Phase 3: ArgoCD GitOps Platform

**Responsibility**: Platform services and application infrastructure deployment

#### Platform Services (via ArgoCD)
```bash
make gitops-status
```

**ArgoCD manages**:
1. **Platform Services**
   - Redis (platform-wide cache)
   - PostgreSQL (platform-wide database)
   - MinIO (platform-wide storage)
   - ElasticMQ (platform-wide message queue)

2. **Application Infrastructure**
   - Application-specific namespaces
   - Resource quotas and limits
   - Network policies
   - Service accounts and RBAC

3. **Continuous Deployment**
   - Monitors Git repository changes
   - Automatically deploys updates
   - Manages application lifecycles
   - Handles rollbacks and recovery

## Service Dependencies

### Local Environment Dependencies
```
Terraform Bootstrap
├── K3d Cluster
├── Kubernetes Infrastructure
├── ArgoCD Installation
└── External Services Validation
    ├── PostgreSQL (Docker)
    ├── MinIO (Docker)
    ├── Redis (Docker) - Optional
    └── ElasticMQ (Docker) - Optional

ArgoCD GitOps
├── Platform Services (K8s)
├── Application Infrastructure
└── Continuous Deployment
```

### AWS Environment Dependencies
```
Terraform Bootstrap
├── AWS Infrastructure
├── EKS Cluster
└── ArgoCD Installation

ArgoCD GitOps
├── Platform Services (K8s)
├── Application Infrastructure
└── Continuous Deployment
```

## Configuration Management

### Environment-Specific Configuration

#### Local Development
- **Cluster**: k3d (Docker-based)
- **Load Balancer**: MetalLB
- **Ingress**: Nginx Ingress Controller
- **External Services**: Docker containers
- **Storage**: Local volumes
- **Domain**: `*.127.0.0.1.nip.io`

#### AWS Production
- **Cluster**: EKS (Managed Kubernetes)
- **Load Balancer**: AWS Application Load Balancer
- **Ingress**: AWS Load Balancer Controller
- **External Services**: AWS managed services (RDS, S3, ElastiCache)
- **Storage**: AWS EBS volumes
- **Domain**: `*.comind.pro`

### Service Configuration

#### Docker Services Configuration
```yaml
# infra/docker/registry/services.yaml
services:
  postgresql:
    enabled: true
    version: "15-alpine"
    port: 5432
    database: "comind_ops_dev"
    username: "postgres"
    password: "postgres"
    
  minio:
    enabled: true
    version: "RELEASE.2023-09-30T07-02-29Z"
    port: 9000
    console_port: 9001
    access_key: "minioadmin"
    secret_key: "minioadmin"
    
  redis:
    enabled: false  # Optional
    version: "7.2-alpine"
    port: 6379
    
  elasticmq:
    enabled: false  # Optional
    version: "1.4.2"
    port: 9324
```

#### ArgoCD Configuration
```yaml
# k8s/kustomize/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: comind-ops-root
spec:
  project: comind-ops-platform
  source:
    repoURL: https://github.com/comind-pro/comind-ops
    targetRevision: main
    path: k8s/kustomize
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Commands Reference

### Infrastructure Setup
```bash
# Complete platform setup
make bootstrap PROFILE=local

# Check infrastructure status
make status

# Check GitOps status
make gitops-status
```

### External Services Management
```bash
# Start external services
make services-setup

# Check service status
make services-status

# Stop services
make services-stop
```

### Application Management
```bash
# Create new application
make new-app-full APP=my-app TEAM=backend

# Deploy application infrastructure
make tf-apply-app APP=my-app

# Check application status
kubectl get pods -n my-app-dev
```

### Monitoring and Access
```bash
# Access monitoring dashboard
make monitoring-access

# Port forward for local access
make monitoring-port-forward

# Start monitoring proxy
make monitoring-proxy
```

## Troubleshooting

### Common Issues

1. **External Services Not Running**
   ```bash
   make services-status
   make services-setup
   ```

2. **ArgoCD Not Accessible**
   ```bash
   kubectl get pods -n argocd
   kubectl port-forward -n argocd svc/argocd-server 8080:80
   ```

3. **Platform Services Not Deployed**
   ```bash
   make gitops-status
   kubectl get applications -n argocd
   ```

4. **Cluster Issues**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

### Health Checks

```bash
# Check all components
make status

# Check external services
make services-status

# Check GitOps status
make gitops-status

# Check platform services
kubectl get pods -n platform-dev
```

## Future Enhancements

1. **Multi-Environment Support**
   - Staging environment
   - Production environment
   - Environment-specific configurations

2. **Advanced Monitoring**
   - Prometheus and Grafana
   - Application metrics
   - Infrastructure monitoring

3. **Security Enhancements**
   - Network policies
   - Pod security standards
   - Secrets management

4. **Backup and Recovery**
   - Automated backups
   - Disaster recovery
   - Data migration

5. **CI/CD Integration**
   - GitHub Actions
   - Automated testing
   - Deployment pipelines