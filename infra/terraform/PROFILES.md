# Terraform Profiles - Service Distribution

This document outlines the clean separation of services between different infrastructure profiles.

## 🏠 LOCAL Profile (`environments/local/`)
**Purpose:** Local development using k3d and Docker services

### Infrastructure
- **Cluster:** k3d (Docker-based Kubernetes)
- **Providers:** Docker, Helm, Kubernetes
- **Load Balancer:** MetalLB (local load balancing)
- **Ingress:** Nginx Ingress Controller

### Docker Services (Local Only)
- ✅ **Docker Provider** - Manages local containers
- ✅ **External Services Validation** - Checks Docker postgres/minio
- ✅ **k3d Cluster** - Docker-based Kubernetes cluster
- ✅ **Local Registry** - Docker registry for local images

### Kubernetes Services
- ✅ **MetalLB** - Local load balancer for k3d
- ✅ **Nginx Ingress** - Local ingress with nip.io domains
- ✅ **ArgoCD** - GitOps with local ingress
- ✅ **Sealed Secrets** - Secret management

### External Dependencies
- Docker Compose services (PostgreSQL, MinIO)
- Local port forwarding (8080, 8443)

---

## ☁️ AWS Profile (`environments/aws/`)
**Purpose:** Production cloud deployment using managed services

### Infrastructure
- **Cluster:** Amazon EKS
- **Providers:** AWS, Helm, Kubernetes (no Docker!)
- **Load Balancer:** AWS Load Balancer Controller
- **Ingress:** AWS Application Load Balancer

### AWS Cloud Services
- ✅ **VPC + Subnets** - Complete network setup
- ✅ **EKS Cluster** - Managed Kubernetes
- ✅ **IAM Roles** - Proper permission management
- ✅ **NAT Gateways** - Internet access for private subnets

### Kubernetes Services
- ✅ **AWS Load Balancer Controller** - Native AWS integration
- ✅ **ArgoCD** - GitOps with LoadBalancer service
- ✅ **Sealed Secrets** - Secret management

### External Dependencies
- AWS managed services (RDS, S3, etc.)
- AWS Load Balancers (ALB/NLB)

### ❌ What's NOT in AWS Profile
- ❌ **No Docker Provider** - Cloud-native services instead
- ❌ **No MetalLB** - Uses AWS Load Balancers
- ❌ **No k3d** - Uses managed EKS
- ❌ **No Docker service validation** - Uses AWS services
- ❌ **No local registry** - Uses ECR or external registries

---

## 🔄 Bootstrap Behavior by Profile

### Local Bootstrap (`make bootstrap` or `make bootstrap PROFILE=local`)
1. ✅ **Start Docker services** (postgres, minio)
2. ✅ **Create k3d cluster**
3. ✅ **Install MetalLB**
4. ✅ **Setup local ingress**
5. ✅ **Validate external services**

### AWS Bootstrap (`make bootstrap PROFILE=aws`)
1. ❌ **Skip Docker services** (uses cloud services)
2. ✅ **Create EKS cluster + VPC**
3. ✅ **Install AWS Load Balancer Controller**
4. ✅ **Setup cloud ingress**
5. ❌ **Skip external service validation**

---

## 🧪 Testing the Separation

```bash
# Verify Docker services only in local
grep -r "docker" infra/terraform/environments/local/   # Should find references
grep -r "docker" infra/terraform/environments/aws/    # Should find NOTHING

# Test profile behavior
make bootstrap PROFILE=local    # Starts Docker services
make bootstrap PROFILE=aws      # Skips Docker services
```

This clean separation ensures:
- 🏠 **Local development** remains fast and self-contained
- ☁️ **Cloud deployment** uses proper managed services  
- 🔧 **No conflicts** between local and cloud resources
- 📦 **Easy maintenance** with environment-specific configurations
