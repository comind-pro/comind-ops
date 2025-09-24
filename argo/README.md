# ArgoCD Configuration

This directory contains the ArgoCD configuration for the comind-ops platform, implementing GitOps principles for automated application deployment and management.

## Directory Structure

```
argo/
├── argocd/
│   └── install/
│       └── values.yaml      # ArgoCD Helm installation values
├── apps/
│   └── applicationset.yaml  # ApplicationSet definitions
├── projects/
│   └── platform-project.yaml # ArgoCD Project configuration
└── README.md               # This file
```

## Components

### 1. ArgoCD Installation (`argocd/install/values.yaml`)
Complete ArgoCD Helm values for production-ready installation:

**Features:**
- **Ingress enabled**: Accessible at `argocd.dev.127.0.0.1.nip.io:8080`
- **RBAC configured**: Admin, Developer, and ReadOnly roles
- **Repository integration**: Connected to Git repositories
- **Security hardened**: Non-root execution, resource limits
- **ApplicationSet enabled**: For automated app management

**Key Configuration:**
- Server runs in insecure mode for local development
- Supports applications in any namespace
- Web-based terminal enabled for debugging
- Customized resource health checks

### 2. ApplicationSet Configuration (`apps/applicationset.yaml`)
Three ApplicationSets for complete platform management:

#### a) `comind-ops-platform-apps`
- **Purpose**: Manages user applications defined in `apps.yaml`
- **Generator**: Matrix generator (apps × environments)
- **Template**: Helm-based applications
- **Features**: Auto-sync, retry logic, environment-specific configs

#### b) `comind-ops-platform-infrastructure`
- **Purpose**: Manages platform infrastructure services
- **Generator**: List generator for infrastructure components
- **Template**: Kustomize-based deployments
- **Components**:
  - Base K8s resources (sync wave -10)
  - Platform services per environment (sync wave 0)

#### c) `comind-ops-platform-root` (App of Apps)
- **Purpose**: Manages the ApplicationSets themselves
- **Pattern**: App of Apps for hierarchical management
- **Auto-sync**: Enabled for GitOps workflow

### 3. Project Configuration (`projects/platform-project.yaml`)
ArgoCD Project defining security boundaries and policies:

**Security Features:**
- **Source repo whitelist**: Only approved repositories
- **Destination control**: Specific namespaces and clusters
- **Resource whitelist**: Allowed Kubernetes resources
- **RBAC integration**: Role-based access control
- **Sync windows**: Controlled deployment windows

## Deployment Order (Sync Waves)

ArgoCD deploys applications in sync waves for proper dependency management:

1. **Wave -10**: Base Kubernetes resources (namespaces, RBAC, policies)
2. **Wave 0**: Platform infrastructure (ElasticMQ, Registry, Backups)
3. **Wave 10+**: User applications (sample-app, custom apps)

## Getting Started

### 1. Install ArgoCD
```bash
# Deploy ArgoCD with our configuration
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argo/argocd/install/values.yaml \
  --wait
```

### 2. Get Admin Password
```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### 3. Access ArgoCD UI
```bash
# Port forward (if ingress not working)
kubectl port-forward service/argocd-server -n argocd 8080:80

# Or access via ingress
open http://argocd.dev.127.0.0.1.nip.io:8080
```

### 4. Deploy ApplicationSets
```bash
# Apply the ApplicationSets (App of Apps pattern)
kubectl apply -f argo/apps/applicationset.yaml
```

### 5. Configure Repository
Update the repository URL in the ApplicationSet files to point to your Git repository:

```yaml
# In argo/apps/applicationset.yaml
repoURL: https://github.com/YOUR-ORG/comind-ops-cloud-setup
```

## Adding New Applications

### 1. Add to apps.yaml
```yaml
apps:
- name: my-new-app
  path: k8s/apps/my-new-app/chart
  namespace: my-new-app
  syncWave: 20
  description: "My new application"
  team: backend
```

### 2. Create Application Structure
```bash
mkdir -p k8s/apps/my-new-app/{chart,values,secrets}
```

### 3. ArgoCD Auto-Discovery
The ApplicationSet will automatically:
- Detect the new app in `apps.yaml`
- Create ArgoCD Applications for all environments
- Deploy using environment-specific values
- Monitor and sync changes

## RBAC and Security

### User Roles
- **Admin**: Full platform access
- **Developer**: Deploy and sync applications
- **ReadOnly**: View applications and logs

### Group Mapping
Configure in `values.yaml`:
```yaml
rbac:
  policy.csv: |
    g, platform-admins, role:admin
    g, platform-developers, role:developer
    g, platform-viewers, role:readonly
```

### Repository Access
Private repositories require secrets:
```bash
# Create repository secret
kubectl create secret generic repo-credentials \
  --from-literal=url=https://github.com/your-org/repo \
  --from-literal=username=token \
  --from-literal=password=<github-token> \
  -n argocd

# Label it for ArgoCD
kubectl label secret repo-credentials \
  argocd.argoproj.io/secret-type=repository \
  -n argocd
```

## Troubleshooting

### Common Issues

1. **Applications not syncing**
   ```bash
   # Check ApplicationSet status
   kubectl get applicationset -n argocd
   kubectl describe applicationset comind-ops-platform-apps -n argocd
   ```

2. **Repository connection failed**
   ```bash
   # Check repository secrets
   kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
   ```

3. **Sync policy issues**
   ```bash
   # Force sync an application
   argocd app sync my-app --force
   ```

### Monitoring

#### ArgoCD Health
```bash
# Check ArgoCD components
kubectl get pods -n argocd
kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd
```

#### Application Status
```bash
# Check all applications
kubectl get applications -n argocd

# Detailed application status
argocd app list
argocd app get my-app
```

## Best Practices

1. **Use sync waves**: Control deployment order with annotations
2. **Environment isolation**: Use separate namespaces and projects
3. **Secret management**: Use SealedSecrets for GitOps secrets
4. **Resource limits**: Apply resource quotas and limits
5. **Health checks**: Configure proper health check URLs
6. **Notifications**: Set up Slack/email notifications for deployments
7. **Backup**: Regularly backup ArgoCD configuration

## Integration

### CI/CD Pipeline Integration
```yaml
# In your CI pipeline
- name: Update image tag
  run: |
    yq eval '.image.tag = "${{ github.sha }}"' -i k8s/apps/my-app/values/dev.yaml
    git add k8s/apps/my-app/values/dev.yaml
    git commit -m "Update my-app to ${{ github.sha }}"
    git push
```

### Monitoring Integration
- Applications automatically expose metrics
- Grafana dashboards available for ArgoCD
- Prometheus scraping configured

This GitOps setup provides a complete, secure, and scalable platform for managing applications across multiple environments with minimal manual intervention.
