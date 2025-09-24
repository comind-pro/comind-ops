# Onboarding Guide

Complete step-by-step guide to get started with the Comind-Ops Platform, from initial setup to deploying your first application.

## Overview

This guide will help you:
- Set up your development environment
- Bootstrap the Comind-Ops Platform  
- Deploy your first application
- Understand the GitOps workflow
- Access monitoring and debugging tools

**Estimated Time**: 30-45 minutes for complete setup

## Prerequisites

### Required Tools

```bash
# macOS (using Homebrew)
brew install kubectl helm terraform k3d docker kubeseal make git

# Linux (Ubuntu/Debian)
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get update && sudo apt-get install helm

# Install terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo apt update && sudo apt install terraform

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubeseal
KUBESEAL_VERSION='0.24.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### System Requirements

- **CPU**: 4+ cores recommended
- **Memory**: 8GB+ RAM recommended  
- **Disk**: 20GB+ free space
- **OS**: macOS, Linux, or WSL2 on Windows
- **Docker**: Docker Desktop or Docker Engine running

### Verify Installation

```bash
# Check all tools are installed
make version
```

## Step 1: Clone and Setup

### 1.1 Clone the Repository

```bash
git clone https://github.com/your-org/comind-ops-cloud-setup.git
cd comind-ops-cloud-setup
```

### 1.2 Verify Repository Structure

```bash
tree -d -L 2
# Expected: argo/, docs/, infra/, k8s/, scripts/
```

## Step 2: Bootstrap the Platform

### 2.1 Complete Bootstrap

```bash
make bootstrap
```

This will:
1. Initialize Terraform
2. Create k3d cluster with networking  
3. Install ArgoCD, ingress-nginx, sealed-secrets
4. Deploy base Kubernetes resources
5. Install platform services (ElasticMQ, Registry, Backups)

**Expected Duration**: 5-10 minutes

### 2.2 Verify Bootstrap

```bash
make status
# Should show: cluster accessible, ArgoCD running, services healthy
```

### 2.3 Troubleshoot Issues

```bash
# Check Docker is running
docker info

# Check cluster
kubectl cluster-info

# Bootstrap components individually if needed
make bootstrap-core      # Just infrastructure
make bootstrap-services  # Just platform services
```

## Step 3: Access the Platform

### 3.1 Get ArgoCD Credentials

```bash
make argo-login
```

Access URLs:
- ArgoCD: http://argocd.dev.127.0.0.1.nip.io:8080
- ElasticMQ: http://elasticmq.dev.127.0.0.1.nip.io:8080
- Registry: http://registry.dev.127.0.0.1.nip.io:8080

### 3.2 Verify Services

```bash
# Test ElasticMQ API
curl http://elasticmq.dev.127.0.0.1.nip.io:8080/queue/default

# Check ArgoCD Applications
kubectl get applications -n argocd
```

## Step 4: Deploy Your First Application

### 4.1 Create a New Application

```bash
make new-app APP=hello-world TEAM=onboarding
```

### 4.2 Customize the Application

```bash
# Use nginx image for demo
cat > k8s/apps/hello-world/values/dev.yaml << 'EOF'
global:
  environment: dev
  domain: dev.127.0.0.1.nip.io
  namespace: hello-world-dev

image:
  repository: nginx
  tag: "1.21"

service:
  port: 80

ingress:
  hosts:
    - host: hello-world.dev.127.0.0.1.nip.io
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
EOF
```

### 4.3 Create and Seal Secrets

```bash
# Create a sample secret
cat > hello-world-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: hello-world-secrets
  namespace: hello-world-dev
stringData:
  API_KEY: "demo-api-key-12345"
  DATABASE_URL: "postgresql://user:pass@postgres:5432/hello"
EOF

# Seal the secret
make seal APP=hello-world ENV=dev FILE=hello-world-secret.yaml

# Clean up plain secret (IMPORTANT!)
rm hello-world-secret.yaml
```

### 4.4 Commit and Deploy

```bash
git add .
git commit -m "Add hello-world application"
git push origin main
```

### 4.5 Monitor Deployment

```bash
# Watch ArgoCD sync
kubectl get applications -n argocd -w

# Check pods
kubectl get pods -n hello-world-dev -w

# Test application
curl http://hello-world.dev.127.0.0.1.nip.io:8080
```

## Step 5: Explore GitOps Workflow

### 5.1 ArgoCD Web UI Tour

1. Login to ArgoCD with credentials from `make argo-login`
2. View applications and sync status
3. Explore application resource tree
4. Review deployment history

### 5.2 Make Configuration Changes

```bash
# Scale to 2 replicas
sed -i 's/replicaCount: 1/replicaCount: 2/' k8s/apps/hello-world/values/dev.yaml

git add -A && git commit -m "Scale to 2 replicas" && git push

# Watch ArgoCD apply changes
kubectl get pods -n hello-world-dev -w
```

## Step 6: Platform Operations

### 6.1 Monitoring

```bash
make status          # Platform health
make logs APP=hello-world  # Application logs
make shell           # Debug shell
```

### 6.2 Backup Operations

```bash
kubectl get cronjobs -n backup-system
kubectl logs -l app=postgres-backup -n backup-system
```

### 6.3 Secret Management

```bash
kubectl get sealedsecrets -A
make seal APP=hello-world ENV=dev FILE=new-secret.yaml
```

## Common Tasks

### Creating More Applications

```bash
# Backend API
make new-app APP=payment-api TEAM=backend --with-database --port=3000

# Frontend App  
make new-app APP=web-ui TEAM=frontend --language=node --port=3000

# Background Worker
make new-app APP=email-worker TEAM=backend --with-queue
```

### Multi-Environment Deployment

```bash
# Create staging configuration
cp k8s/apps/hello-world/values/dev.yaml k8s/apps/hello-world/values/stage.yaml
# Edit stage.yaml for staging-specific settings

# Seal staging secrets  
make seal APP=hello-world ENV=stage FILE=stage-secret.yaml

git add -A && git commit -m "Add staging environment" && git push
```

### Environment Management

```bash
make bootstrap ENV=stage    # Bootstrap staging
make tf-apply ENV=prod      # Deploy to production  
make status ENV=prod        # Check production status
```

## Troubleshooting

### Common Issues

#### Bootstrap Fails
```bash
docker info                 # Check Docker
make cleanup && make bootstrap  # Clean retry
```

#### Applications Won't Deploy
```bash
kubectl logs -n argocd deployment/argocd-server
argocd app sync my-app-dev  # Manual sync
```

#### Secrets Not Working
```bash
kubectl get pods -n sealed-secrets
make seal APP=my-app ENV=dev FILE=secret.yaml --force
```

#### Can't Access Services
```bash
kubectl get ingress -A
kubectl port-forward service/my-app 8080:80 -n my-app-dev
```

### Getting Help

- **Documentation**: Check `docs/` directory
- **Script Help**: `./scripts/<script>.sh --help`
- **Makefile Help**: `make help`
- **Debugging**: `make debug APP=my-app`

## Next Steps

### Development Workflow
- Use `make shell` for cluster debugging
- Port forward services for testing
- Monitor with `make logs`

### Production Readiness  
- Set up monitoring and alerting
- Configure backup and disaster recovery
- Implement security scanning

## Conclusion

You now have:
- ✅ Complete Comind-Ops Platform running locally
- ✅ ArgoCD managing GitOps workflows
- ✅ Your first application deployed  
- ✅ Understanding of platform operations

The platform is ready for your team to build and deploy applications with confidence, security, and automation.

**Happy coding!** 🚀