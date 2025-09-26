# Makefile Documentation

This document provides comprehensive documentation for all available Makefile targets in the comind-ops Platform.

## Quick Reference Card

```bash
# Essential Commands
make help                    # Show all available commands
make bootstrap              # Complete cluster setup
make argo-login            # Get ArgoCD credentials
make status                # Show platform status

# Application Management
make new-app APP=my-api     # Create new application
make list-apps             # List all applications  
make seal APP=app ENV=dev FILE=secret.yaml  # Seal secrets

# Terraform Operations
make tf ENV=dev APP=core COMMAND=plan      # Terraform operations
make tf-apply ENV=prod APP=my-app          # Apply changes

# Development & Debugging
make logs APP=my-app       # View application logs
make shell                 # Debug shell in cluster
make validate             # Validate all configurations
```

## Target Categories

### 🏗️ Infrastructure & Bootstrap

| Target | Description | Example |
|--------|-------------|---------|
| `bootstrap` | Complete cluster setup | `make bootstrap` |
| `cleanup` | Destroy cluster (DESTRUCTIVE) | `make cleanup ENV=dev` |
| `up` | Alias for bootstrap | `make up` |
| `down` | Alias for cleanup | `make down` |

**Bootstrap Process:**
1. Initialize Terraform
2. Deploy core infrastructure (k3d, ArgoCD, ingress)
3. Wait for cluster readiness
4. Apply base Kubernetes resources
5. Deploy platform services

### 🔐 ArgoCD & GitOps

| Target | Description | Example |
|--------|-------------|---------|
| `argo-login` | Get ArgoCD credentials | `make argo-login` |
| `argo-apps` | List ArgoCD applications | `make argo-apps` |

**ArgoCD Integration:**
- Web UI accessible at `http://argocd.dev.127.0.0.1.nip.io:8080`
- Default username: `admin`
- Password retrieved from Kubernetes secret

### 📱 Application Management

| Target | Description | Example |
|--------|-------------|---------|
| `new-app` | Create new application | `make new-app APP=payment-api TEAM=backend` |
| `list-apps` | List all applications | `make list-apps` |

**New App Features:**
- Creates complete Helm chart structure
- Generates environment-specific values
- Registers in `apps.yaml` for ArgoCD
- Includes security defaults and best practices

### 🔒 Secret Management

| Target | Description | Example |
|--------|-------------|---------|
| `seal` | Seal secret for GitOps | `make seal APP=my-app ENV=dev FILE=secret.yaml` |

**Secret Workflow:**
1. Create plain Kubernetes secret file
2. Use `make seal` to encrypt with SealedSecrets
3. Commit only the `.sealed.yaml` file
4. ArgoCD deploys and decrypts automatically

### 🏗️ Terraform Operations

| Target | Description | Example |
|--------|-------------|---------|
| `tf` | Run Terraform command | `make tf ENV=dev APP=core COMMAND=plan` |
| `tf-plan` | Plan changes | `make tf-plan ENV=dev APP=my-app` |
| `tf-apply` | Apply changes | `make tf-apply ENV=prod APP=core` |
| `tf-output` | Show outputs | `make tf-output ENV=dev APP=core` |

**Terraform Directories:**
- **Core**: `infra/terraform/core/` - Cluster infrastructure
- **Apps**: `k8s/apps/<app>/terraform/` - App-specific resources
- **Environments**: `infra/terraform/envs/<env>/` - Environment-specific

### 🚀 Deployment & Operations

| Target | Description | Example |
|--------|-------------|---------|
| `deploy` | Deploy platform services | `make deploy` |
| `status` | Show platform status | `make status` |
| `logs` | Show application logs | `make logs APP=my-api` |

**Status Information Includes:**
- Cluster connectivity
- ArgoCD health
- Platform services status
- Quick access URLs

### ✅ Validation & Testing

| Target | Description | Example |
|--------|-------------|---------|
| `validate` | Validate all configurations | `make validate` |
| `lint` | Lint code and configs | `make lint` |
| `test` | Run platform tests | `make test` |

**Validation Includes:**
- Terraform configuration validation
- Kubernetes manifest validation
- Helm chart linting
- Connectivity tests

### 🔧 Development & Debugging

| Target | Description | Example |
|--------|-------------|---------|
| `shell` | Open debug shell in cluster | `make shell` |
| `logs` | View application logs | `make logs APP=my-api` |

## Variables Reference

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `ENV` | Target environment | `dev` | `make bootstrap ENV=prod` |
| `APP` | Application name | `sample-app` | `make new-app APP=payment-api` |
| `COMMAND` | Terraform command | `plan` | `make tf COMMAND=apply` |
| `TEAM` | Team name for new apps | `platform` | `make new-app TEAM=backend` |
| `FILE` | File path for secrets | - | `make seal FILE=secret.yaml` |

## Environment Management

### Development Environment
```bash
make bootstrap ENV=dev          # Bootstrap development
make new-app APP=my-app ENV=dev # Create app in dev
make tf-apply ENV=dev APP=core  # Deploy infrastructure
```

### Staging Environment  
```bash
make bootstrap ENV=stage        # Bootstrap staging
make deploy ENV=stage          # Deploy services
make status ENV=stage          # Check status
```

### Production Environment
```bash
make bootstrap ENV=prod         # Bootstrap production
make tf-plan ENV=prod APP=core  # Plan before applying
make tf-apply ENV=prod APP=core # Apply with confirmation
```

## Advanced Usage

### Creating Applications with Dependencies

```bash
# Create API with database
make new-app APP=user-api TEAM=backend
# Edit k8s/apps/user-api/chart/values.yaml to add database config
make seal APP=user-api ENV=dev FILE=user-secret.yaml

# Deploy database infrastructure  
make tf-apply ENV=dev APP=user-api

# Application will be deployed by ArgoCD automatically
```

### Multi-Environment Deployments

```bash
# Deploy to all environments
for env in dev stage prod; do
  make bootstrap ENV=$env
done

# Promote application across environments
make seal APP=my-app ENV=stage FILE=stage-secret.yaml
make tf-apply ENV=stage APP=my-app
# ArgoCD handles the deployment
```

### Disaster Recovery

```bash
# Backup (manual process)
kubectl get all -A -o yaml > cluster-backup.yaml
make tf-output ENV=prod > terraform-outputs.txt

# Restore
make bootstrap ENV=prod                    # Recreate infrastructure
kubectl apply -f cluster-backup.yaml     # Restore applications (if needed)
```

## Troubleshooting

### Common Issues and Solutions

1. **Bootstrap fails with timeout**
   ```bash
   # Check cluster status
   kubectl cluster-info
   # Retry with specific steps
   make tf-apply ENV=dev APP=core
   kubectl apply -k k8s/base/
   ```

2. **ArgoCD not accessible**
   ```bash
   # Check ArgoCD pods
   kubectl get pods -n argocd
   # Port forward if needed
   kubectl port-forward service/argocd-server -n argocd 8080:80
   ```

3. **Secrets not working**
   ```bash
   # Check sealed-secrets controller
   kubectl get pods -n sealed-secrets
   # Verify secret format
   kubectl apply --dry-run=client -f secret.yaml
   ```

4. **Terraform state issues**
   ```bash
   # List terraform state
   make tf ENV=dev APP=core COMMAND=state
   # Force unlock if needed  
   terraform -chdir=infra/terraform/core force-unlock <lock-id>
   ```

### Debug Commands

```bash
# Platform health check
make test

# Detailed status
make status
kubectl get all -A

# Check logs
make logs APP=my-app
kubectl logs -n argocd deployment/argocd-server

# Network connectivity
kubectl run debug --rm -i --tty --image=alpine/curl --restart=Never -- sh
```

## Best Practices

### Development Workflow

1. **Start with development environment**
   ```bash
   make bootstrap ENV=dev
   make new-app APP=my-service TEAM=my-team
   ```

2. **Develop and test locally**
   ```bash
   # Build and push to registry
   docker build -t registry.dev.127.0.0.1.nip.io:8080/my-service:dev-latest .
   docker push registry.dev.127.0.0.1.nip.io:8080/my-service:dev-latest
   ```

3. **Update values and secrets**
   ```bash
   # Edit k8s/apps/my-service/values/dev.yaml
   make seal APP=my-service ENV=dev FILE=dev-secret.yaml
   ```

4. **Commit and deploy**
   ```bash
   git add -A
   git commit -m "Add my-service application"
   git push
   # ArgoCD automatically deploys
   ```

### Production Deployment

1. **Always plan first**
   ```bash
   make tf-plan ENV=prod APP=my-service
   ```

2. **Deploy in stages**
   ```bash
   make tf-apply ENV=stage APP=my-service  # Test in staging first
   make tf-apply ENV=prod APP=my-service   # Then production
   ```

3. **Monitor deployment**
   ```bash
   make status ENV=prod
   make logs APP=my-service ENV=prod
   ```

### Security Guidelines

1. **Never commit plain secrets**
   ```bash
   # Always use sealed secrets
   make seal APP=my-app ENV=prod FILE=prod-secret.yaml
   rm prod-secret.yaml  # Delete plain file
   ```

2. **Use least privilege**
   - Applications run as non-root
   - Resource limits applied
   - Network policies enforced

3. **Regular updates**
   ```bash
   make validate  # Regular validation
   make lint     # Code quality checks
   ```

This Makefile provides a complete developer experience for the comind-ops Platform, from initial setup to production deployment, with built-in safety checks and comprehensive automation.
