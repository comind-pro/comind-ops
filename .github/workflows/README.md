# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Comind-Ops Platform GitOps deployment pipeline.

## Workflows

### 1. GitOps Deployment Pipeline (`gitops-deploy.yml`)

**Trigger:** Push to `main` or `develop` branches, or pull requests

**Purpose:** Automated deployment of applications and infrastructure changes

**Jobs:**
- **validate**: Validates Helm charts and ArgoCD applications
- **build-and-push**: Builds and pushes Docker images to registry
- **update-image-tags**: Updates image tags in values files based on branch
- **deploy**: Syncs ArgoCD applications
- **notify**: Sends deployment status notifications

**Features:**
- Branch-based environment deployment (main → prod, develop → stage, others → dev)
- Automatic image tag updates
- Helm chart validation
- ArgoCD application synchronization
- Deployment notifications

### 2. App Registration Pipeline (`app-registration.yml`)

**Trigger:** Repository dispatch event or manual workflow dispatch

**Purpose:** Automated registration of new applications

**Jobs:**
- **validate-registration**: Validates app registration parameters
- **create-helm-chart**: Creates Helm chart structure
- **create-argocd-apps**: Creates ArgoCD application manifests
- **commit-changes**: Commits changes to repository
- **notify-completion**: Sends completion notifications

**Features:**
- Automated Helm chart generation
- ArgoCD application creation
- Environment-specific configurations
- Git commit automation
- Registration validation

## Usage

### Deploying Changes

1. **Development**: Push to feature branch → triggers validation only
2. **Staging**: Push to `develop` branch → deploys to stage environment
3. **Production**: Push to `main` branch → deploys to prod environment

### Registering New Applications

#### Via Web Interface
1. Access the app registry web interface
2. Fill in application details
3. Submit registration form
4. Pipeline automatically creates Helm chart and ArgoCD applications

#### Via API
```bash
curl -X POST http://localhost:5000/api/apps \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "type": "user",
    "team": "backend",
    "repository": "https://github.com/my-org/my-app",
    "description": "My awesome application"
  }'
```

#### Via GitHub API
```bash
curl -X POST https://api.github.com/repos/OWNER/REPO/dispatches \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{
    "event_type": "app-registered",
    "client_payload": {
      "app_name": "my-app",
      "app_type": "user",
      "team": "backend",
      "repository_url": "https://github.com/my-org/my-app"
    }
  }'
```

## Configuration

### Required Secrets

Add these secrets to your GitHub repository:

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions
- `KUBECONFIG`: Kubernetes cluster configuration (for deployment)
- `ARGOCD_SERVER`: ArgoCD server URL
- `ARGOCD_TOKEN`: ArgoCD authentication token

### Environment Variables

- `REGISTRY`: Container registry URL (default: ghcr.io)
- `IMAGE_NAME`: Base image name (default: repository name)

## Customization

### Adding New Environments

1. Update the workflow to include new environment
2. Add environment-specific values files
3. Create ArgoCD applications for new environment
4. Update branch-to-environment mapping

### Custom Validation

Add custom validation steps in the `validate` job:

```yaml
- name: Custom Validation
  run: |
    # Add your custom validation logic here
    ./scripts/custom-validate.sh
```

### Custom Notifications

Add notification steps in the `notify` job:

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    channel: '#deployments'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Troubleshooting

### Common Issues

1. **Helm chart validation fails**
   - Check Chart.yaml syntax
   - Verify values files are valid YAML
   - Ensure all required fields are present

2. **ArgoCD sync fails**
   - Verify ArgoCD server is accessible
   - Check application manifests are valid
   - Ensure target namespace exists

3. **Image build fails**
   - Check Dockerfile syntax
   - Verify base image is available
   - Ensure build context is correct

### Debugging

Enable debug logging by adding:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Manual Intervention

For manual deployment or rollback:

```bash
# Sync specific application
argocd app sync my-app-dev

# Rollback application
argocd app rollback my-app-dev

# Check application status
argocd app get my-app-dev
```

## Security Considerations

- Use least-privilege service accounts
- Rotate tokens regularly
- Validate all inputs
- Use signed container images
- Enable image scanning
- Implement network policies
- Use secrets management

## Monitoring

Monitor pipeline execution:

- GitHub Actions tab in repository
- ArgoCD UI for application status
- Kubernetes events and logs
- Application health endpoints
- Prometheus metrics (if configured)
