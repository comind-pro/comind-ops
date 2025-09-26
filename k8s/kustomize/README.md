# Kustomize Directory

This directory contains ArgoCD Application manifests that define how Helm charts are deployed using GitOps principles.

## Structure

```
kustomize/
├── platform/        # Platform service applications
│   ├── dev/         # Development environment
│   │   ├── elasticmq.yaml
│   │   ├── registry.yaml
│   │   └── monitoring.yaml
│   ├── stage/       # Staging environment
│   └── prod/        # Production environment
└── apps/            # Application deployments
    ├── dev/         # Development environment
    │   ├── monitoring-dashboard.yaml
    │   ├── hello-world.yaml
    │   └── [user-app].yaml
    ├── stage/       # Staging environment
    └── prod/        # Production environment
```

## Application Pattern

Each YAML file is an ArgoCD Application resource that:

1. **Points to a Helm chart** in `charts/` directory
2. **Specifies environment-specific values** from `values/{env}.yaml`
3. **Defines sync policy** (auto-sync, manual approval, etc.)
4. **Sets target namespace** and cluster
5. **Configures retry and health check policies**

## Example Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-dashboard-dev
  namespace: argocd
  labels:
    app: monitoring-dashboard
    environment: dev
    team: platform
spec:
  project: platform-project
  source:
    repoURL: https://github.com/comind-pro/comind-ops
    targetRevision: main
    path: k8s/charts/apps/monitoring-dashboard
    helm:
      valueFiles:
        - values/dev.yaml
      parameters:
        - name: image.tag
          value: "dev"
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring-dashboard-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
```

## Environment Management

### Development (`dev/`)
- **Auto-sync enabled**: Changes deployed automatically
- **Resource limits**: Lower CPU/memory for cost efficiency
- **Debug features**: Enabled logging, debugging tools
- **External access**: Via port-forwarding or nip.io domains

### Staging (`stage/`)
- **Auto-sync enabled**: Changes deployed automatically
- **Production-like**: Similar resources to production
- **Testing features**: Integration tests, performance monitoring
- **External access**: Via staging domains

### Production (`prod/`)
- **Manual sync**: Requires approval for deployments
- **High availability**: Multiple replicas, anti-affinity
- **Security hardened**: Network policies, pod security
- **External access**: Via production domains with TLS

## App Registration

Applications are registered through:

1. **Platform Apps**: Added to `k8s/kustomize/apps/{env}/` by platform team
2. **User Apps**: Registered via app registration mechanism
3. **Platform Services**: Managed in `k8s/kustomize/platform/{env}/`

## Sync Policies

### Platform Services
- **Auto-sync**: Enabled for platform stability
- **Prune**: Enabled to clean up removed resources
- **Self-heal**: Enabled to maintain desired state

### Applications
- **Dev/Stage**: Auto-sync enabled
- **Production**: Manual sync with approval workflow
- **Prune**: Enabled for all environments
- **Self-heal**: Enabled for all environments

## Naming Conventions

- **Application names**: `{app-name}-{environment}`
- **Namespaces**: `{app-name}-{environment}`
- **Labels**: Consistent across all resources
- **Annotations**: Include team, contact, and metadata

## Integration with CI/CD

1. **Image updates**: CI/CD updates image tags in values files
2. **Config changes**: Git commits trigger ArgoCD sync
3. **Environment promotion**: Move changes between environments
4. **Rollback**: Use ArgoCD UI or CLI for quick rollbacks
