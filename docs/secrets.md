# Secrets Management

Complete guide to managing secrets securely in the Comind-Ops Platform using Bitnami Sealed Secrets for GitOps workflows.

## Overview

The Comind-Ops Platform uses **Bitnami Sealed Secrets** to enable secure, Git-based secret management. This approach allows secrets to be encrypted and stored in version control while maintaining security and enabling GitOps workflows.

### Key Concepts

- **Plain Secrets**: Standard Kubernetes secrets with sensitive data in plaintext
- **Sealed Secrets**: Encrypted secrets that can be safely stored in Git
- **Controller**: Sealed Secrets controller running in the cluster that decrypts secrets
- **GitOps**: Secrets are managed through Git commits and ArgoCD synchronization

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Developer     │    │   Git Repository │    │   Kubernetes        │
│                 │    │                  │    │   Cluster           │
│ 1. Create       │    │ 3. Commit        │    │                     │
│    plain secret │───▶│    sealed secret │───▶│ 5. Sealed Secrets   │
│                 │    │                  │    │    Controller       │
│ 2. Seal with    │    │ 4. ArgoCD detects│    │    decrypts         │
│    kubeseal     │    │    changes       │    │                     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                 │                        │
                                 │                        ▼
                                 │               ┌─────────────────────┐
                                 │               │ 6. Plain Secret     │
                                 └──────────────▶│    available for    │
                                                 │    application      │
                                                 └─────────────────────┘
```

## Quick Start

### 1. Create a Plain Secret

```bash
cat > my-app-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: my-app-dev
stringData:
  DATABASE_PASSWORD: "super-secret-password"
  API_KEY: "your-api-key-here"
  JWT_SECRET: "jwt-secret-token"
EOF
```

### 2. Seal the Secret

Using our automation script (recommended):
```bash
./scripts/seal-secret.sh my-app dev my-app-secret.yaml
```

### 3. Commit and Deploy

```bash
# Remove the plain secret file (IMPORTANT!)
rm my-app-secret.yaml

# Add the sealed secret to Git
git add k8s/apps/my-app/secrets/dev.sealed.yaml
git commit -m "Add sealed secrets for my-app dev environment"
git push origin main

# ArgoCD will automatically sync and decrypt the secret
```

## Prerequisites

### Install kubeseal CLI

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
KUBESEAL_VERSION='0.24.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### Verify Controller

```bash
kubectl get pods -n sealed-secrets
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

## Advanced Usage

### Multi-Environment Secrets

```bash
# Development
./scripts/seal-secret.sh my-app dev dev-secret.yaml

# Staging  
./scripts/seal-secret.sh my-app stage stage-secret.yaml

# Production
./scripts/seal-secret.sh my-app prod prod-secret.yaml
```

### Different Secret Types

#### TLS Secrets
```bash
kubectl create secret tls my-app-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=my-app-dev \
  --dry-run=client -o yaml > tls-secret.yaml

./scripts/seal-secret.sh my-app dev tls-secret.yaml
```

#### Docker Registry Secrets
```bash
kubectl create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  --docker-email=user@example.com \
  --namespace=my-app-dev \
  --dry-run=client -o yaml > registry-secret.yaml

./scripts/seal-secret.sh my-app dev registry-secret.yaml
```

## Secret Rotation

### Automated Rotation Process

```bash
#!/bin/bash
APP_NAME="my-app"
ENV="prod"

# Generate new database password
NEW_PASSWORD=$(openssl rand -base64 32)

# Create new secret
cat > ${APP_NAME}-secret-new.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${APP_NAME}-secrets
  namespace: ${APP_NAME}-${ENV}
stringData:
  DATABASE_PASSWORD: "$NEW_PASSWORD"
EOF

# Seal and deploy
./scripts/seal-secret.sh $APP_NAME $ENV ${APP_NAME}-secret-new.yaml
rm ${APP_NAME}-secret-new.yaml

# Commit changes
git add k8s/apps/${APP_NAME}/secrets/${ENV}.sealed.yaml
git commit -m "Rotate database password for ${APP_NAME} ${ENV}"
git push

# Restart application
kubectl rollout restart deployment/${APP_NAME} -n ${APP_NAME}-${ENV}
```

## Security Best Practices

### Development Guidelines

1. **Never commit plain secrets**:
   ```bash
   # .gitignore already configured
   echo "*secret*.yaml" >> .gitignore
   echo "!*.sealed.yaml" >> .gitignore
   ```

2. **Use descriptive secret names**:
   ```yaml
   name: payment-api-secrets  # Good
   name: secrets             # Bad
   ```

3. **Namespace isolation**:
   ```yaml
   metadata:
     name: my-app-secrets
     namespace: my-app-prod  # Always specify
   ```

### Rotation Schedule

- **Database passwords**: Monthly
- **API keys**: Quarterly  
- **Certificates**: Before expiration
- **SSH keys**: Annually

## Troubleshooting

### Common Issues

#### Sealed Secret Won't Decrypt
```bash
kubectl get sealedsecrets -n my-app-dev
kubectl describe sealedsecret my-app-secrets -n my-app-dev
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

#### Wrong Namespace Error
```bash
# Re-seal with correct namespace
./scripts/seal-secret.sh my-app dev secret.yaml --namespace my-app-dev
```

#### Controller Not Running
```bash
kubectl get pods -n sealed-secrets
# If down, reinstall:
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

### Emergency Access

```bash
# Get secret value directly
kubectl get secret my-app-secrets -n my-app-prod -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d

# Emergency secret creation (bypass GitOps)
kubectl create secret generic emergency-access \
  --from-literal=ADMIN_PASSWORD="emergency-password" \
  --namespace=my-app-prod
```

## Integration with Applications

### Environment Variables

```yaml
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-app-secrets
      key: DATABASE_PASSWORD
```

### Volume Mounts

```yaml
volumeMounts:
- name: secret-volume
  mountPath: /etc/secrets
  readOnly: true

volumes:
- name: secret-volume
  secret:
    secretName: my-app-secrets
```

## Makefile Integration

The platform provides convenient Make targets:

```bash
# Create example secret file
make seal-example APP=my-app

# Seal a secret
make seal APP=my-app ENV=dev FILE=secret.yaml

# Help with seal command
make help | grep seal
```

This sealed secrets system provides enterprise-grade security while maintaining developer productivity and GitOps principles. All secrets are encrypted at rest in Git, access is controlled through repository permissions, and the audit trail is complete and immutable.