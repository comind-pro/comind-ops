# Comind-Ops Platform

Complete cloud-native platform built on Kubernetes, featuring automated GitOps workflows, comprehensive observability, and enterprise-grade security. The Comind-Ops Platform provides everything you need to deploy, manage, and scale applications in both local development and cloud environments.

## ✨ Key Features

- **🏗️ Multi-Environment Support**: Seamless deployment across local (k3d) and AWS environments
- **🚀 GitOps Automation**: ArgoCD-powered continuous deployment with Helm charts
- **🔒 Enterprise Security**: Sealed secrets, RBAC, network policies, and Pod Security Standards
- **📊 Complete Observability**: Monitoring dashboard, centralized logging, and health checks
- **🛠️ Developer Experience**: One-command app scaffolding, automated infrastructure provisioning
- **📦 External Data Services**: PostgreSQL and MinIO running as optimized Docker containers
- **🎯 Production Ready**: High availability, disaster recovery, security scanning, and compliance

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/comind-pro/comind-ops.git
cd comind-ops

# 2. Bootstrap the platform (one command setup!)
make bootstrap PROFILE=local

# 3. Access services
make argo-login                    # ArgoCD dashboard
make services-status               # Check external services
make monitoring-access             # Monitoring dashboard
open http://localhost:9001         # MinIO console

# 4. Create your first application with infrastructure
make new-app-full APP=my-api TEAM=backend

# 5. Check GitOps status
make gitops-status
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     COMIND-OPS PLATFORM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   DEVELOPMENT   │  │     STAGING     │  │   PRODUCTION    │  │
│  │                 │  │                 │  │                 │  │
│  │ • Local k3d     │  │ • AWS Cloud     │  │ • AWS Cloud     │  │
│  │ • Auto Deploy   │  │ • Tag Deploy    │  │ • Manual Approval│  │
│  │ • Debug Mode    │  │ • Prod-like     │  │ • Blue/Green    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    KUBERNETES CLUSTER                       │ │
│  │                                                             │ │
│  │ ArgoCD • Sealed Secrets • Ingress • MetalLB • ElasticMQ    │ │
│  │ Applications • Platform Services • Monitoring • Security    │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              EXTERNAL DATA SERVICES (infra/docker)          │ │
│  │                                                             │ │
│  │  ┌─────────────────┐            ┌─────────────────────────┐ │ │
│  │  │   PostgreSQL    │◀──────────▶│         MinIO          │ │ │
│  │  │   (port 5432)   │            │  (ports 9000/9001)     │ │ │
│  │  │ • Multi-DB      │            │ • S3 Compatible        │ │ │
│  │  │ • Automated     │            │ • Web Console          │ │ │
│  │  │   Backups       │            │ • Lifecycle Policies   │ │ │
│  │  └─────────────────┘            └─────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   AUTOMATION    │  │    SECURITY     │  │   OBSERVABILITY │  │
│  │                 │  │                 │  │                 │  │
│  │ • Terraform     │  │ • RBAC          │  │ • Metrics       │  │
│  │ • Helm Charts   │  │ • Network Pol.  │  │ • Logs          │  │
│  │ • Scripts       │  │ • Pod Security  │  │ • Health Checks │  │
│  │ • CI/CD         │  │ • Secrets Mgmt  │  │ • Alerting      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🛠 Technologies

**Infrastructure & Platform:**
- **Kubernetes**: k3d locally, AWS EKS in cloud
- **Terraform**: Infrastructure as code for all environments
- **ArgoCD**: GitOps continuous deployment and application management
- **Helm**: Package management for Kubernetes applications

**External Data Services:**
- **PostgreSQL 16**: Primary database with multi-environment support
- **MinIO**: S3-compatible object storage with web console
- **Automated Backups**: Scheduled backups to MinIO with retention policies

**Platform Services:**
- **ElasticMQ**: SQS-compatible message queue
- **Docker Registry**: Private container registry with cleanup automation
- **Sealed Secrets**: Secure secret management for GitOps
- **MetalLB**: Load balancer for local development
- **Ingress-Nginx**: HTTP/HTTPS ingress controller

**Security & Governance:**
- **RBAC**: Role-based access control throughout the platform
- **Network Policies**: Microsegmentation and traffic control
- **Pod Security Standards**: Enforce security best practices
- **Resource Quotas**: Prevent resource exhaustion

---

## 🚀 Platform Operations

### **🏗️ Infrastructure Management**

```bash
# Complete platform setup
make bootstrap PROFILE=local      # Full platform bootstrap

# External services management  
make services-setup               # Start PostgreSQL & MinIO
make services-stop                # Stop external services
make services-status              # Check service health
make services-backup              # Create backups

# Kubernetes cluster operations
make validate                     # Validate all configurations
make status                       # Platform status overview
make gitops-status                # ArgoCD GitOps status
```

### **🔧 Application Development**

```bash
# Create new applications
make new-app-full APP=my-service TEAM=backend    # Full-stack app with DB
make new-app-api APP=my-api TEAM=backend         # API service
make new-app-worker APP=worker TEAM=data        # Background worker

# Infrastructure provisioning (via ArgoCD GitOps)
make new-app-full APP=my-service TEAM=backend    # Create app with infrastructure
make gitops-status                                # Check deployment status

# Secret management
make seal-secret APP=my-service ENV=dev FILE=secrets.yaml
```

### **🧪 Testing & Validation**

```bash
# Comprehensive testing
make test                         # Run all tests
make test-unit                    # Unit tests only
make test-integration            # Integration tests
make test-e2e                    # End-to-end tests
make test-performance            # Performance tests

# Component-specific testing
make test-helm                   # Test Helm charts
make test-terraform              # Test Terraform modules
make test-ci                     # Test CI/CD components
```

## 📦 External Services Architecture

The Comind-Ops Platform uses external Docker containers for data services, providing better persistence and management:

### PostgreSQL Database
- **Access**: `localhost:5432`
- **Databases**: Multi-environment setup (dev, stage, prod)
- **Features**: Optimized configuration, automated backups, health monitoring
- **Management**: `make services-*` commands

### MinIO Object Storage  
- **API**: `http://localhost:9000`
- **Console**: `http://localhost:9001`
- **Features**: S3-compatible, lifecycle policies, bucket management
- **Buckets**: app-data, backups, logs, uploads, artifacts

### Benefits
- ✅ **Data Persistence**: Survives cluster recreation
- ✅ **Performance**: Reduced Kubernetes overhead
- ✅ **Management**: Direct access for debugging and administration
- ✅ **Backup**: Integrated automated backup solution

---

## 🔒 Security Features

### **Secrets Management**
- **Sealed Secrets**: Encrypt secrets for safe Git storage
- **Secret Rotation**: Automated credential lifecycle management
- **Scope Isolation**: Namespace and environment-specific secrets

### **Network Security**
- **Network Policies**: Default-deny with explicit allow rules
- **Pod Security**: Enforce security standards across all workloads
- **RBAC**: Fine-grained authorization throughout the platform

### **Compliance**
- **Security Scanning**: Automated vulnerability detection
- **Policy Enforcement**: OPA-based policy validation
- **Audit Logging**: Comprehensive access and change tracking

---

## 📊 CI/CD Pipeline

### **5 Specialized Workflows**
1. **CI Pipeline**: Validation, linting, security scanning
2. **CD Pipeline**: Multi-environment deployment automation
3. **Terraform Pipeline**: Infrastructure change management
4. **Security Pipeline**: Comprehensive security validation
5. **Helm Pipeline**: Chart testing and validation

### **Features**
- ✅ **Multi-environment Promotion**: Dev → Staging → Production
- ✅ **Security Integration**: 7 security tools across all workflows
- ✅ **Infrastructure as Code**: Terraform automation with drift detection
- ✅ **Container Security**: Image scanning and SBOM generation

---

## 🎯 Getting Started Guide

### **1. Prerequisites**
```bash
# Install required tools
brew install docker kubectl helm terraform k3d yamllint

# Verify installation
make check-deps                  # Check all dependencies
```

### **2. Bootstrap Platform**
```bash
# Complete setup
make bootstrap                   # One command to rule them all!

# Verify installation
make status                      # Check all components
```

### **3. Deploy First Application**  
```bash
# Create sample application
make new-app-full APP=hello-world TEAM=platform

# Deploy infrastructure
make tf-apply-app APP=hello-world

# Check deployment
kubectl get pods -n hello-world-dev
```

### **4. Access Services**
- **ArgoCD**: `http://argocd.dev.127.0.0.1.nip.io:8080`
- **Monitoring Dashboard**: `make monitoring-access`
- **MinIO Console**: `http://localhost:9001`
- **PostgreSQL**: `psql -h localhost -p 5432 -U postgres -d comind_ops_dev`

---

## 📚 Documentation

### **Core Guides**
- **[Infrastructure Flow](docs/INFRASTRUCTURE_FLOW.md)**: Complete infrastructure flow and phases
- **[Architecture](docs/infra-architecture.md)**: Complete system architecture and design
- **[Onboarding](docs/onboarding.md)**: Step-by-step developer onboarding
- **[External Services](docs/external-services.md)**: PostgreSQL and MinIO management
- **[Secrets Management](docs/secrets.md)**: Secure secret handling workflows
- **[CI/CD Pipelines](docs/ci-cd.md)**: Automation and deployment workflows

### **Quick References**
- **[Makefile Targets](Makefile.md)**: All available commands
- **[Testing Framework](tests/README.md)**: Testing strategies and tools

---

## 🚀 Production Ready Features

### **High Availability**
- Multi-zone deployment support
- Automated failover and recovery
- Load balancing and traffic management
- Data replication and backup strategies

### **Scalability**  
- Horizontal pod autoscaling
- Cluster autoscaling integration
- Resource optimization and monitoring
- Performance tuning guidelines

### **Observability**
- Comprehensive metrics collection
- Centralized logging aggregation  
- Distributed tracing capabilities
- Custom dashboards and alerting

### **Security Hardening**
- Pod security standards enforcement
- Network microsegmentation
- Vulnerability scanning and management
- Compliance framework integration

---

## 🎊 What's Included

**✅ Complete Platform Stack**
- Infrastructure automation with Terraform
- GitOps deployment with ArgoCD  
- External data services (PostgreSQL, MinIO)
- Platform services (ElasticMQ, Registry)
- Security and governance frameworks

**✅ Developer Experience**
- One-command platform bootstrap
- Application scaffolding automation
- Comprehensive testing framework
- Rich documentation and guides

**✅ Production Operations**
- Multi-environment support
- Automated backup and recovery
- Comprehensive monitoring
- Security scanning and compliance

**✅ Enterprise Features**  
- RBAC and access control
- Secret management workflows
- Network security policies
- Audit logging and compliance

---

The **Comind-Ops Platform** provides everything needed to build, deploy, and operate cloud-native applications at enterprise scale! 🚀