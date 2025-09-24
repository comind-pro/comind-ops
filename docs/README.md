# Comind-Ops Platform Documentation

Welcome to the comprehensive documentation for the Comind-Ops Platform - a cloud-native infrastructure platform built on Kubernetes with GitOps principles.

## Quick Start

**New to the platform?** Start here:

1. **[📚 Onboarding Guide](onboarding.md)** - Complete setup walkthrough (30-45 minutes)
2. **[🏗️ Architecture Overview](infra-architecture.md)** - Understand the platform design
3. **[🔐 Secrets Management](secrets.md)** - Learn secure secret workflows

## Documentation Structure

### Core Platform Docs

| Document | Description | Audience |
|----------|-------------|----------|
| **[Onboarding Guide](onboarding.md)** | Step-by-step platform setup | New developers |
| **[Infrastructure Architecture](infra-architecture.md)** | System design and components | Platform engineers |  
| **[Secrets Management](secrets.md)** | Sealed Secrets workflows | All developers |

### Operational Guides

| Document | Description | Location |
|----------|-------------|----------|
| **[Makefile Documentation](../Makefile.md)** | All available make targets | Root directory |
| **[Scripts Documentation](../scripts/README.md)** | Automation script usage | scripts/ directory |
| **[ArgoCD Guide](../argo/README.md)** | GitOps configuration | argo/ directory |
| **[Platform Services](../k8s/platform/README.md)** | Service documentation | k8s/platform/ directory |
| **[Base Resources](../k8s/base/README.md)** | Security and governance | k8s/base/ directory |

### Development Resources

| Resource | Description | Location |
|----------|-------------|----------|
| **[Task Management](../task.md)** | Project roadmap and tasks | Root directory |
| **[Main README](../README.md)** | Project overview and workflow | Root directory |
| **[.gitignore Guide](../.gitignore)** | Version control best practices | Root directory |

## Quick Reference

### Essential Commands

```bash
# Platform Management
make help                    # Show all commands
make bootstrap              # Complete setup
make status                 # Platform health
make cleanup               # Destroy everything

# Application Management  
make new-app APP=my-api     # Create application
make list-apps             # Show all apps
make logs APP=my-api       # View logs

# Secret Management
make seal APP=my-app ENV=dev FILE=secret.yaml
make argo-login           # Get ArgoCD access

# Infrastructure Operations
make tf ENV=dev COMMAND=plan    # Terraform operations
make validate                   # Validate configs
make test                      # Run tests
```

### Access URLs (Local Development)

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | http://argocd.dev.127.0.0.1.nip.io:8080 | GitOps Management |
| ElasticMQ | http://elasticmq.dev.127.0.0.1.nip.io:8080 | Message Queue |
| Registry | http://registry.dev.127.0.0.1.nip.io:8080 | Container Registry |
| Apps | http://\<app\>.dev.127.0.0.1.nip.io:8080 | Your Applications |

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────┐
│                    comind-ops PLATFORM                    │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │     DEV     │  │   STAGE     │  │      PROD       │  │
│  │             │  │             │  │                 │  │
│  │ • k3d local │  │ • Cloud K8s │  │ • HA Cloud K8s  │  │
│  │ • Fast iter │  │ • Testing   │  │ • Auto-scaling  │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────┤
│                   PLATFORM SERVICES                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │  ElasticMQ  │  │   Registry  │  │    Backups      │  │
│  │  (Queues)   │  │ (Containers)│  │ (Data Safety)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────┤
│                      GITOPS CORE                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │   ArgoCD    │  │ Kubernetes  │  │   Git Repo      │  │
│  │  (Deploy)   │  │  (Runtime)  │  │ (Source Truth) │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Getting Help

### Troubleshooting Resources

1. **[Onboarding Guide - Troubleshooting](onboarding.md#troubleshooting)** - Common setup issues
2. **[Secrets Guide - Troubleshooting](secrets.md#troubleshooting)** - Secret management issues  
3. **[Makefile Help](../Makefile.md#troubleshooting)** - Command-specific problems
4. **[Script Documentation](../scripts/README.md#troubleshooting)** - Automation script issues

### Debug Commands

```bash
# Platform Health
make status                    # Overall platform status
make test                     # Run all validation tests  
make validate                 # Validate configurations

# Application Debugging
make debug APP=my-app         # Application debug info
make logs APP=my-app          # Application logs
make shell                    # Debug shell in cluster

# Infrastructure Debugging  
kubectl get all -A            # All Kubernetes resources
kubectl get events --sort-by=.metadata.creationTimestamp  # Recent events
kubectl describe pod <pod-name> -n <namespace>  # Pod details
```

### Getting Support

1. **Check documentation** first - most questions are covered
2. **Use help commands**: `make help`, `./scripts/<script> --help`
3. **Review logs**: `make logs APP=my-app`, `kubectl logs`
4. **Test connectivity**: `make test`, `kubectl cluster-info`

## Contributing to Documentation

### Documentation Standards

- **Clear headings** with proper hierarchy (H1 > H2 > H3)
- **Code examples** with syntax highlighting
- **Commands with explanations** of what they do
- **Troubleshooting sections** for common issues
- **Links between documents** for easy navigation

### Adding Documentation

1. **Update existing docs** when making platform changes
2. **Add new guides** for significant new features
3. **Include examples** and real-world usage patterns
4. **Test all commands** before documenting them

### Documentation Checklist

- [ ] Clear purpose and audience identified
- [ ] Prerequisites listed
- [ ] Step-by-step instructions provided
- [ ] Commands tested and verified  
- [ ] Troubleshooting section included
- [ ] Links to related documentation added
- [ ] Examples use realistic scenarios

## Platform Components

### Core Infrastructure
- **k3d/k3s**: Lightweight Kubernetes for local development
- **ArgoCD**: GitOps continuous deployment
- **Sealed Secrets**: Encrypted secret management
- **nginx-ingress**: HTTP/HTTPS load balancing
- **MetalLB**: Load balancer for local development

### Platform Services  
- **ElasticMQ**: AWS SQS-compatible message queuing
- **Docker Registry**: Private container image storage
- **PostgreSQL**: Primary database with automated backups
- **MinIO**: S3-compatible object storage
- **Backup Services**: Automated data protection

### Development Tools
- **Terraform**: Infrastructure as Code
- **Helm**: Kubernetes package management
- **Make**: Build automation and workflows
- **Shell Scripts**: Platform automation
- **Git**: Version control and GitOps source

## Security Model

### Defense in Depth
1. **Network Security**: Network policies, ingress TLS
2. **Identity & Access**: RBAC, service accounts, least privilege
3. **Secrets Management**: Sealed secrets, rotation policies
4. **Container Security**: Non-root, read-only filesystems  
5. **Resource Governance**: Quotas, limits, policies

### Best Practices
- Never commit plain secrets to Git
- Use namespace isolation for multi-tenancy
- Apply resource limits to all workloads
- Regular secret rotation schedules
- Monitor and audit all access

## Environments

### Development
- **Purpose**: Local development and testing
- **Infrastructure**: k3d cluster on developer machine
- **Features**: Hot reload, debug tools, fast feedback

### Staging
- **Purpose**: Pre-production testing and validation
- **Infrastructure**: Cloud Kubernetes cluster
- **Features**: Production-like setup, integration testing

### Production  
- **Purpose**: Live application serving
- **Infrastructure**: High-availability cloud setup
- **Features**: Auto-scaling, comprehensive monitoring, disaster recovery

---

This documentation provides everything you need to understand, operate, and extend the comind-ops Platform. Start with the [Onboarding Guide](onboarding.md) and explore from there based on your role and needs.

**Questions?** Check the troubleshooting sections or use the debug commands provided above.
