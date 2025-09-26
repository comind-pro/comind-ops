# Comind-Ops Platform Documentation

Complete documentation for the Comind-Ops Platform covering architecture, operations, and development workflows.

## 📋 Documentation Index

### **🏗️ Infrastructure & Architecture**
- **[Infrastructure Architecture](infra-architecture.md)**: Complete system architecture and design patterns
- **[External Services](external-services.md)**: PostgreSQL and MinIO Docker container management
- **[Onboarding Guide](onboarding.md)**: Step-by-step developer onboarding and setup

### **🔒 Security & Operations**  
- **[Secrets Management](secrets.md)**: Sealed Secrets workflows and best practices
- **[CI/CD Pipelines](ci-cd.md)**: Automation workflows and deployment strategies

### **📁 Infrastructure Structure**
```
infra/
├── docker/                    # External services (PostgreSQL, MinIO)
│   ├── docker-compose.yml     # Service orchestration
│   ├── postgres/              # Database setup and config
│   └── scripts/               # Backup automation
└── terraform/                 # Infrastructure as Code
    ├── core/                  # Cluster infrastructure
    ├── modules/app_skel/      # Application templates
    └── envs/                  # Environment configs
```

## 🚀 Quick Reference

### **Platform Commands**
```bash
# Complete platform bootstrap
make bootstrap

# External services management
make services-start           # Start PostgreSQL & MinIO
make services-status          # Check service health
make services-backup          # Create backups

# Platform status and access
make status                   # Overall platform status
make argo-login              # Access ArgoCD UI
```

### **Development Workflows**
```bash
# Create new application
make new-app-full APP=my-service TEAM=backend

# Infrastructure operations
make tf-plan-app APP=my-service
make tf-apply-app APP=my-service

# Secret management
make seal-secret APP=my-service ENV=dev FILE=secrets.yaml
```

### **Testing & Validation**
```bash
# Run comprehensive tests
make test                     # All test suites
make test-unit               # Unit tests only
make test-integration        # Integration tests
make test-e2e               # End-to-end tests
```

## 🏗️ Architecture at a Glance

```
┌─────────────────────────────────────────────────────────┐
│                    COMIND-OPS PLATFORM                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │   KUBERNETES    │  │ EXTERNAL SERVICES │              │
│  │     CLUSTER     │  │  (infra/docker)  │              │
│  │                 │  │                  │              │
│  │ • ArgoCD        │◀─┤ • PostgreSQL     │              │
│  │ • Applications  │  │ • MinIO          │              │
│  │ • Platform Svcs │  │ • Auto Backups   │              │
│  └─────────────────┘  └─────────────────┘              │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                    AUTOMATION                       │ │
│  │ Terraform • Helm • Scripts • CI/CD • Testing       │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 🎯 Core Features

- **🐳 External Data Services**: PostgreSQL and MinIO in `infra/docker/`
- **☸️ Kubernetes Platform**: Full GitOps with ArgoCD
- **🏗️ Infrastructure as Code**: Terraform modules and environments
- **🔒 Enterprise Security**: RBAC, secrets, network policies
- **🧪 Comprehensive Testing**: Multi-level test automation
- **📊 Complete Observability**: Monitoring, logging, health checks

## 🚀 Getting Started

1. **Prerequisites**: `make check-deps`
2. **Bootstrap**: `make bootstrap` 
3. **Verify**: `make status`
4. **Deploy App**: `make new-app-full APP=hello TEAM=demo`

## 🔧 Troubleshooting Resources

### **Common Issues**
- **Services not starting**: Check `make services-status`
- **Cluster issues**: Verify with `kubectl cluster-info`
- **ArgoCD problems**: Check `make argo-status`

### **Debug Commands**
```bash
# External services
make services-logs           # View service logs
docker ps                   # Check containers

# Kubernetes debugging  
kubectl get pods -A         # All pods status
kubectl logs -n argocd deployment/argocd-server

# Platform validation
make validate               # Validate all configs
make test-ci               # Test CI/CD components
```

### **Log Locations**
- **External Services**: `infra/docker/` container logs
- **Kubernetes**: `kubectl logs` commands
- **ArgoCD**: Available via UI and `kubectl logs`
- **Platform**: Service-specific logging

## 📈 Advanced Topics

### **Multi-Environment Deployment**
- Development: Auto-deploy from `main` branch
- Staging: Tag-triggered deployments
- Production: Manual approval workflow

### **Security Hardening**
- Pod Security Standards enforcement
- Network policy microsegmentation  
- Sealed Secrets for GitOps-safe secret management
- RBAC with least-privilege principles

### **Performance Optimization**
- External services for data persistence
- Resource quotas and limits
- Horizontal Pod Autoscaling
- Cluster autoscaling integration

## 💡 Best Practices

### **Development**
- Use `make new-app-*` for consistent app structure
- Test locally with `make test-*` commands
- Validate configs with `make validate`

### **Operations**
- Monitor with `make status`
- Regular backups with `make services-backup`
- Use GitOps for all deployments

### **Security**
- Rotate secrets regularly
- Review RBAC permissions
- Monitor security scan results
- Keep dependencies updated

---

This documentation provides everything you need to understand, operate, and extend the Comind-Ops Platform. Start with the [Onboarding Guide](onboarding.md) and explore from there based on your role and needs.

**Questions?** Check the troubleshooting sections or use the debug commands provided above.