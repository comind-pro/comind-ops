# Automation Scripts

This directory contains automation scripts for the comind-ops platform that simplify common development and deployment tasks.

## Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `new-app.sh` | Scaffold new applications | `./scripts/new-app.sh <app-name> [options]` |
| `seal-secret.sh` | Seal secrets for GitOps | `./scripts/seal-secret.sh <app> <env> <secret-file>` |
| `tf.sh` | Manage Terraform operations | `./infra/terraform/scripts/tf.sh <env> [app] [command]` |

## 1. New App Scaffolding (`new-app.sh`)

Creates a complete application structure with Helm charts, environment-specific values, and sealed secret templates.

### Usage
```bash
# Basic application
./scripts/new-app.sh my-api --team backend --port 3000

# Application with database
./scripts/new-app.sh my-api --team backend --with-database

# Frontend application
./scripts/new-app.sh my-frontend --team frontend --language node --port 3000

# Worker with queue integration
./scripts/new-app.sh my-worker --team backend --with-queue --sync-wave 20
```

### Generated Structure
```
k8s/apps/my-app/
├── chart/                  # Helm chart with templates
├── values/                 # Environment-specific values
├── secrets/                # Sealed secret templates  
├── terraform/              # App infrastructure (optional)
└── README.md              # App documentation
```

### Features
- **Language-specific configs**: Node.js, Python, Go, Java support
- **Platform integrations**: Database, cache, queue configurations
- **Security defaults**: Non-root containers, read-only filesystems
- **GitOps ready**: Automatic apps.yaml registration
- **Multi-environment**: Dev/stage/prod configurations

## 2. Secret Sealing (`seal-secret.sh`)

Encrypts Kubernetes secrets using Bitnami Sealed Secrets for secure GitOps workflows.

### Prerequisites
```bash
# Install kubeseal CLI
brew install kubeseal  # macOS
# or
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
```

### Usage
```bash
# Create a plain secret first
cat > secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: my-app-dev
stringData:
  DATABASE_PASSWORD: "super-secret-password"
  API_KEY: "your-api-key-here"
EOF

# Seal the secret
./scripts/seal-secret.sh my-app dev secret.yaml

# Clean up plain secret (IMPORTANT!)
rm secret.yaml
```

### Features
- **Validation**: Checks secret format and cluster connectivity
- **Namespace handling**: Auto-updates namespaces as needed
- **Git integration**: Shows commit instructions
- **Verification**: Optional sealed secret verification
- **Safety checks**: Prevents overwriting without confirmation

## 3. Terraform Management (`tf.sh`)

Manages Terraform operations across different environments and applications with proper workspace isolation.

### Usage
```bash
# Core infrastructure
./infra/terraform/scripts/tf.sh dev core plan          # Plan infrastructure changes
./infra/terraform/scripts/tf.sh dev core apply         # Apply infrastructure changes
./infra/terraform/scripts/tf.sh dev core output        # Show terraform outputs

# Application resources
./infra/terraform/scripts/tf.sh dev my-app plan         # Plan app-specific resources
./infra/terraform/scripts/tf.sh dev my-app apply --auto-approve
./infra/terraform/scripts/tf.sh prod my-app destroy     # Destroy production resources

# Advanced operations
./infra/terraform/scripts/tf.sh dev core apply --target aws_instance.example
./infra/terraform/scripts/tf.sh dev core plan --var-file custom.tfvars
```

### Supported Directories
- **Core**: `infra/terraform/core/` - Cluster infrastructure
- **Environment**: `infra/terraform/envs/<env>/<app>/` - Environment-specific resources
- **Application**: `k8s/apps/<app>/terraform/` - App-specific resources

### Features
- **Workspace management**: Automatic environment workspace selection
- **Safety checks**: Confirmation prompts for destructive operations
- **Variable injection**: Automatic environment and app name variables
- **State management**: Remote state with locking support

## Quick Start Workflow

### 1. Create a New Application
```bash
# Scaffold the application
./scripts/new-app.sh payment-api --team backend --port 8080 --with-database

# The app is automatically added to apps.yaml and ArgoCD will detect it
```

### 2. Add Secrets
```bash
# Create secret file
cat > payment-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: payment-api-secrets
  namespace: payment-api-dev
stringData:
  DATABASE_PASSWORD: "dev-password-123"
  STRIPE_SECRET_KEY: "sk_test_..."
  JWT_SECRET: "your-jwt-secret"
EOF

# Seal and commit
./scripts/seal-secret.sh payment-api dev payment-secret.yaml
rm payment-secret.yaml  # Clean up plain secret
git add k8s/apps/payment-api/secrets/dev.sealed.yaml
git commit -m "Add sealed secrets for payment-api dev"
```

### 3. Deploy Infrastructure (if needed)
```bash
# Deploy core infrastructure first
./infra/terraform/scripts/tf.sh dev core apply

# Deploy app-specific resources  
./infra/terraform/scripts/tf.sh dev payment-api apply
```

### 4. Push and Deploy
```bash
# Push to Git - ArgoCD will automatically deploy
git push origin main

# Check deployment status
kubectl get applications -n argocd
kubectl get pods -n payment-api-dev
```

## Environment Variables

Scripts respect these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TEAM` | Default team for new apps | `platform` |
| `PORT` | Default port for new apps | `8080` |
| `LANGUAGE` | Default language | `generic` |

Example:
```bash
export TEAM=backend
export PORT=3000
./scripts/new-app.sh my-api  # Uses team=backend, port=3000
```

## Integration with GitOps

These scripts are designed to work seamlessly with the ArgoCD ApplicationSet:

1. **new-app.sh** → Registers apps in `apps.yaml` → ArgoCD creates Applications
2. **seal-secret.sh** → Creates sealed secrets → ArgoCD deploys them securely  
3. **tf.sh** → Provisions infrastructure → Applications deploy on top

## Troubleshooting

### Common Issues

1. **Script permission denied**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **kubeseal not found**
   ```bash
   # macOS
   brew install kubeseal
   # Linux  
   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
   ```

3. **Terraform not initialized**
   ```bash
   ./infra/terraform/scripts/tf.sh dev core init
   ```

4. **Sealed secrets controller not running**
   ```bash
   kubectl get pods -n sealed-secrets
   # If missing, install:
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
   ```

### Debug Mode

Run scripts with debug output:
```bash
bash -x ./scripts/new-app.sh my-app
```

### Getting Help

Each script has comprehensive help:
```bash
./scripts/new-app.sh --help
./scripts/seal-secret.sh --help  
./infra/terraform/scripts/tf.sh --help
```

## Best Practices

1. **Always test in dev first**: Deploy and test in development environment
2. **Use sealed secrets**: Never commit plain secrets to Git
3. **Backup before destroy**: Take snapshots before running terraform destroy
4. **Follow naming conventions**: Use lowercase, hyphen-separated names
5. **Review changes**: Always review terraform plans before applying
6. **Clean up**: Delete temporary files and unused resources

## Security Considerations

1. **Plain secrets**: Always delete plain secret files after sealing
2. **Git history**: Never commit secrets, even temporarily
3. **Access control**: Limit who can run production operations  
4. **Audit trail**: All operations are logged for compliance
5. **Least privilege**: Scripts use minimal required permissions

These automation scripts provide a complete developer experience for the comind-ops platform, from application creation to secure deployment across multiple environments.
