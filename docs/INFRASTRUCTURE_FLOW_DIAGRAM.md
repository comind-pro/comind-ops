# Infrastructure Flow Diagram

## Complete Infrastructure Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           COMINDS-OPS PLATFORM FLOW                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PHASE 1: TERRAFORM INFRASTRUCTURE SETUP                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    make bootstrap PROFILE=local                        │   │
│  │                                                                         │   │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │   │
│  │  │   K3d Cluster   │    │   Kubernetes    │    │     ArgoCD      │    │   │
│  │  │   Creation      │───▶│  Infrastructure │───▶│   Installation  │    │   │
│  │  │                 │    │                 │    │                 │    │   │
│  │  │ • k3d cluster   │    │ • Namespaces    │    │ • Helm install  │    │   │
│  │  │ • kubeconfig    │    │ • MetalLB       │    │ • GitOps config │    │   │
│  │  │ • Networking    │    │ • Ingress       │    │ • RBAC setup    │    │   │
│  │  │                 │    │ • Sealed Secrets│    │ • Repository    │    │   │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘    │   │
│  │                                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │              External Services Validation                       │   │   │
│  │  │                                                                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │   │
│  │  │  │ PostgreSQL  │  │    MinIO    │  │    Redis    │             │   │   │
│  │  │  │ (REQUIRED)  │  │ (REQUIRED)  │  │ (OPTIONAL)  │             │   │   │
│  │  │  │             │  │             │  │             │             │   │   │
│  │  │  │ Port: 5432  │  │ Port: 9000  │  │ Port: 6379  │             │   │   │
│  │  │  │ DB: dev     │  │ Console:    │  │ No auth     │             │   │   │
│  │  │  │ User: postgres│ │ 9001       │  │             │             │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  PHASE 2: DOCKER EXTERNAL SERVICES (Local Only)                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    make services-setup                                 │   │
│  │                                                                         │   │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │   │
│  │  │   PostgreSQL    │    │     MinIO       │    │     Redis       │    │   │
│  │  │   Container     │    │   Container     │    │   Container     │    │   │
│  │  │                 │    │                 │    │                 │    │   │
│  │  │ • Database      │    │ • Object Storage│    │ • Cache         │    │   │
│  │  │ • Persistence   │    │ • S3 Compatible │    │ • Session Store│    │   │
│  │  │ • Backups       │    │ • Web Console   │    │ • Queue         │    │   │
│  │  │                 │    │                 │    │                 │    │   │
│  │  └─────────────────┘    └─────────────────┘    └─────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  PHASE 3: ARGOCD GITOPS PLATFORM                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    ArgoCD GitOps Deployment                            │   │
│  │                                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │                Platform Services (K8s)                         │   │   │
│  │  │                                                                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │   │
│  │  │  │   Redis     │  │ PostgreSQL  │  │    MinIO    │             │   │   │
│  │  │  │ (Platform)  │  │ (Platform)  │  │ (Platform)  │             │   │   │
│  │  │  │             │  │             │  │             │             │   │   │
│  │  │  │ Namespace:  │  │ Namespace:  │  │ Namespace:  │             │   │   │
│  │  │  │ platform-dev│  │ platform-dev│  │ platform-dev│             │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │              Application Infrastructure                         │   │   │
│  │  │                                                                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │   │
│  │  │  │ Monitoring  │  │   User      │  │   Platform  │             │   │   │
│  │  │  │ Dashboard   │  │   Apps      │  │   Apps      │             │   │   │
│  │  │  │             │  │             │  │             │             │   │   │
│  │  │  │ Namespace:  │  │ Namespace:  │  │ Namespace:  │             │   │   │
│  │  │  │ monitoring  │  │ user-apps   │  │ platform    │             │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │              Continuous Deployment                              │   │   │
│  │  │                                                                 │   │   │
│  │  │  • Git repository monitoring                                    │   │   │
│  │  │  • Automatic deployments                                        │   │   │
│  │  │  • Configuration management                                     │   │   │
│  │  │  • Rollback capabilities                                        │   │   │
│  │  │  • Health monitoring                                            │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Service Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVICE DEPENDENCIES                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TERRAFORM BOOTSTRAP                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │   │
│  │  │   K3d       │───▶│ Kubernetes  │───▶│   ArgoCD    │ │   │
│  │  │  Cluster    │    │    Infra    │    │             │ │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  EXTERNAL SERVICES VALIDATION                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │   │
│  │  │ PostgreSQL  │    │    MinIO    │    │    Redis    │ │   │
│  │  │ (REQUIRED)  │    │ (REQUIRED)  │    │ (OPTIONAL)  │ │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ARGOCD GITOPS                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │   │
│  │  │ Platform    │    │ Application │    │ Continuous  │ │   │
│  │  │ Services    │    │ Infra       │    │ Deployment  │ │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT COMPARISON                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LOCAL DEVELOPMENT (PROFILE=local)                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  Cluster: k3d (Docker-based)                           │   │
│  │  Load Balancer: MetalLB                                │   │
│  │  Ingress: Nginx Ingress Controller                     │   │
│  │  External Services: Docker containers                  │   │
│  │  Storage: Local volumes                                │   │
│  │  Domain: *.127.0.0.1.nip.io                           │   │
│  │                                                         │   │
│  │  Required Services:                                     │   │
│  │  • PostgreSQL (Docker)                                 │   │
│  │  • MinIO (Docker)                                      │   │
│  │                                                         │   │
│  │  Optional Services:                                     │   │
│  │  • Redis (Docker)                                      │   │
│  │  • ElasticMQ (Docker)                                  │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  AWS PRODUCTION (PROFILE=aws)                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  Cluster: EKS (Managed Kubernetes)                     │   │
│  │  Load Balancer: AWS Application Load Balancer          │   │
│  │  Ingress: AWS Load Balancer Controller                 │   │
│  │  External Services: AWS managed services               │   │
│  │  Storage: AWS EBS volumes                              │   │
│  │  Domain: *.comind.pro                                  │   │
│  │                                                         │   │
│  │  Managed Services:                                      │   │
│  │  • RDS PostgreSQL                                      │   │
│  │  • S3 Object Storage                                   │   │
│  │  • ElastiCache Redis                                   │   │
│  │  • SQS Message Queue                                   │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Command Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        COMMAND FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. INFRASTRUCTURE SETUP                                        │
│     make bootstrap PROFILE=local                                │
│     ├── Check dependencies                                      │
│     ├── Start external services                                 │
│     ├── Initialize Terraform                                    │
│     ├── Deploy core infrastructure                              │
│     ├── Wait for cluster readiness                              │
│     ├── Apply base Kubernetes resources                         │
│     ├── Deploy platform services                                │
│     ├── Setup GitOps with ArgoCD                                │
│     └── Deploy monitoring dashboard                             │
│                                                                 │
│  2. EXTERNAL SERVICES MANAGEMENT                                │
│     make services-setup                                         │
│     ├── Start PostgreSQL                                        │
│     ├── Start MinIO                                             │
│     ├── Start Redis (optional)                                  │
│     └── Start ElasticMQ (optional)                              │
│                                                                 │
│  3. APPLICATION DEPLOYMENT                                      │
│     make new-app-full APP=my-app TEAM=backend                   │
│     ├── Create application structure                            │
│     ├── Generate Helm chart                                     │
│     ├── Create ArgoCD application                               │
│     └── Deploy via GitOps                                       │
│                                                                 │
│  4. MONITORING AND ACCESS                                       │
│     make monitoring-access                                      │
│     ├── Check ingress availability                              │
│     ├── Setup port forwarding                                   │
│     └── Start monitoring proxy                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```