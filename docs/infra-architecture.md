# Infrastructure Architecture

Complete architectural overview of the Comind-Ops Platform including components, data flows, security model, and operational patterns.

## System Overview

The Comind-Ops Platform is a cloud-native infrastructure platform built on Kubernetes with GitOps principles, designed to support both local development (k3d) and cloud deployments (AWS/DigitalOcean).

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                               COMIND-OPS PLATFORM                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   DEVELOPMENT   │  │     STAGING      │  │   PRODUCTION    │  │   MONITORING    │ │
│  │                 │  │                  │  │                 │  │                 │ │
│  │ • Local k3d     │  │ • Cloud K8s      │  │ • Cloud K8s     │  │ • Prometheus    │ │
│  │ • Hot Reload    │  │ • Pre-prod Test  │  │ • HA Setup      │  │ • Grafana       │ │
│  │ • Debug Tools   │  │ • Load Testing   │  │ • Auto-scaling  │  │ • AlertManager  │ │
│  └─────────────────┘  └──────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Control Plane

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTROL PLANE                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────────┐    │
│  │   ArgoCD     │    │  Kubernetes  │    │   Git Repo      │    │
│  │              │    │   API        │    │                 │    │
│  │ • GitOps     │◄──►│ • Cluster    │◄──►│ • Source Truth │    │
│  │ • Sync       │    │ • Resources  │    │ • Audit Trail  │    │
│  │ • Health     │    │ • Events     │    │ • Rollback     │    │
│  └──────────────┘    └──────────────┘    └─────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

#### ArgoCD (GitOps Engine)
- **Purpose**: Automated application deployment and lifecycle management
- **Components**:
  - Server: Web UI and API
  - Repository Server: Git operations
  - Application Controller: Kubernetes resource management
  - ApplicationSets: Multi-environment deployment automation

#### Kubernetes Cluster
- **Local**: k3d cluster with 1 server + 2 agents
- **Cloud**: Managed Kubernetes (EKS/DigitalOcean)
- **Features**:
  - Multi-tenancy with namespace isolation
  - Resource quotas and limits
  - Network policies for security
  - Horizontal Pod Autoscaling

### 2. Platform Services Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                        PLATFORM SERVICES                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │ ElasticMQ   │  │ Registry    │  │ Postgres    │  │  MinIO  │ │
│  │             │  │             │  │             │  │         │ │
│  │ • SQS API   │  │ • Private   │  │ • Primary   │  │ • S3    │ │
│  │ • Queues    │  │ • Retention │  │ • HA Setup  │  │ • Backups│ │
│  │ • DLQ       │  │ • Auth      │  │ • Backups   │  │ • Buckets│ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  Ingress    │  │   Secrets   │  │   Backup    │  │Monitoring│ │
│  │             │  │             │  │             │  │         │ │
│  │ • nginx     │  │ • Sealed    │  │ • CronJobs  │  │ • Metrics│ │
│  │ • TLS       │  │ • Rotation  │  │ • Retention │  │ • Logs   │ │
│  │ • LB        │  │ • GitOps    │  │ • Recovery  │  │ • Alerts │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

#### Key Platform Services

- **ElasticMQ**: AWS SQS-compatible message queuing with DLQ support
- **Docker Registry**: Private container storage with retention policies
- **Backup Services**: Automated PostgreSQL and MinIO backups
- **Ingress**: nginx-based load balancing and TLS termination
- **Secrets**: Sealed Secrets for secure GitOps workflows

### 3. Infrastructure Layer

#### Local Development (k3d)
- **Docker**: Container runtime with Postgres and MinIO
- **k3s**: Lightweight Kubernetes distribution
- **MetalLB**: Load balancer for service exposure

#### Cloud Production (EKS/DigitalOcean)
- **Managed Kubernetes**: EKS/DOKS with auto-scaling
- **RDS**: Managed PostgreSQL with HA setup
- **S3**: Object storage with lifecycle rules

## Network Architecture

### Local Network Topology

```
Developer Machine (127.0.0.1)
├── Docker Network (172.18.0.0/16)
│   └── k3d Cluster
│       ├── Service Network (10.43.0.0/16)
│       ├── Pod Network (10.42.0.0/16)
│       └── LoadBalancer IPs (172.18.255.200-250)
└── Host Port Mappings:
    ├── 8080  → Ingress HTTP
    ├── 8443  → Ingress HTTPS
    ├── 5000  → Docker Registry
    └── 6443  → Kubernetes API
```

### Service Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | `http://argocd.dev.127.0.0.1.nip.io:8080` | GitOps Management |
| ElasticMQ | `http://elasticmq.dev.127.0.0.1.nip.io:8080` | Message Queue UI |
| Registry | `http://registry.dev.127.0.0.1.nip.io:8080` | Container Registry |
| Applications | `http://<app>.dev.127.0.0.1.nip.io:8080` | App Access |

## Security Architecture

### Defense in Depth

1. **Network Security**: Network policies with default deny
2. **Identity & Access**: RBAC with least privilege
3. **Secrets Management**: Sealed secrets with rotation
4. **Container Security**: Non-root, read-only filesystems
5. **Resource Governance**: Quotas and limits

### RBAC Model

```
Platform Administrators (cluster-admin)
├── ArgoCD Administrators (argocd:admin)
├── Platform Developers (platform:developer)  
└── Platform Viewers (platform:readonly)
```

## Data Flow Architecture

### GitOps Workflow

```
1. Developer commits → 2. Git updated → 3. ArgoCD detects → 
4. Compare state → 5. Apply changes → 6. K8s updated → 7. Apps running
```

### Application Deployment

```
Source Code → Build (CI/CD) → Deploy (ArgoCD) → Monitor
    ↓              ↓              ↓              ↓
Git Repo      Docker Registry   Kubernetes    Observability
```

## Backup Strategy

### Automated Backups

- **PostgreSQL**: Daily pg_dumpall with compression (3 AM)
- **MinIO**: Incremental bucket mirroring (4 AM) 
- **Configuration**: Git-based with multi-region replication
- **Retention**: 7 days default, configurable per environment

### Recovery Procedures

1. **Infrastructure**: `make bootstrap ENV=prod`
2. **Data**: Restore from compressed backups
3. **Applications**: ArgoCD auto-sync from Git

## Monitoring and Observability

### Metrics Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and management

### Key Metrics
- Infrastructure: CPU, Memory, Disk, Network
- Applications: Response times, Error rates, Throughput  
- Platform: ArgoCD sync, Backup success, Cert expiry

## Scaling Patterns

### Horizontal Pod Autoscaling
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70
```

### Environment-Specific Scaling
- **Development**: Single replicas, minimal resources
- **Staging**: Production-like setup for testing
- **Production**: HA with auto-scaling and resource optimization

## Integration Patterns

### Platform Service Integration
- **Database**: Direct connection via service DNS
- **Queue**: ElasticMQ SQS-compatible API
- **Storage**: MinIO S3-compatible API
- **Secrets**: Sealed secrets mounted as env vars or volumes

### External Systems
- **Third-party APIs**: Via ingress with TLS termination
- **Monitoring**: Prometheus scraping and Grafana visualization
- **Backup**: External storage for disaster recovery

## Deployment Environments

### Development
- **Purpose**: Local development and testing
- **Infrastructure**: k3d cluster on developer machine
- **Features**: Hot reload, debug tools, fast iteration

### Staging  
- **Purpose**: Pre-production testing
- **Infrastructure**: Cloud Kubernetes cluster
- **Features**: Production-like setup, load testing, integration tests

### Production
- **Purpose**: Live application serving
- **Infrastructure**: HA cloud setup with auto-scaling
- **Features**: Blue/green deployments, comprehensive monitoring, backup/recovery

This architecture provides enterprise-grade reliability, security, and scalability while maintaining developer productivity through automation and GitOps principles.