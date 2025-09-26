# Helm Charts Directory

This directory contains Helm charts for the Comind-Ops Platform following GitOps principles.

## Structure

```
charts/
├── platform/        # Platform services
│   ├── elasticmq/   # ElasticMQ message queue
│   ├── registry/    # Container registry
│   ├── monitoring/  # Monitoring stack
│   └── ...
└── apps/            # Application charts
    ├── monitoring-dashboard/  # Platform monitoring dashboard
    ├── hello-world/          # Sample application
    └── ...
```

## Chart Guidelines

### Platform Charts (`charts/platform/`)
- Platform services that support applications
- Managed by platform team
- Auto-sync enabled for platform services
- Environment-agnostic with values overrides

### Application Charts (`charts/apps/`)
- User and platform applications
- Managed by respective teams
- Environment-specific configurations
- Image tags updated by CI/CD

## Chart Structure

Each chart should follow this structure:

```
[chart-name]/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── values/             # Environment-specific values
│   ├── dev.yaml
│   ├── stage.yaml
│   └── prod.yaml
└── templates/          # Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── ...
```

## Values Management

- **Default values**: Common settings in `values.yaml`
- **Environment values**: Overrides in `values/{env}.yaml`
- **Sensitive values**: Use Kubernetes secrets or Sealed Secrets
- **Image tags**: Managed by CI/CD pipeline

## Chart Development

1. Create chart structure using `helm create [name]`
2. Customize templates for your application
3. Define environment-specific values
4. Test with `helm template` and `helm install --dry-run`
5. Register in ArgoCD via kustomize applications

## Integration with ArgoCD

Charts are deployed via ArgoCD Applications defined in `k8s/kustomize/`:

- **Platform Services**: `k8s/kustomize/platform/{env}/[service].yaml`
- **Applications**: `k8s/kustomize/apps/{env}/[app].yaml`

Each ArgoCD Application points to a chart and specifies:
- Source repository and path
- Target revision (branch/tag)
- Values files to use
- Sync policy and options
