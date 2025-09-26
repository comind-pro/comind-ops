# ArgoCD Repository Configuration

This guide explains how to configure ArgoCD to work with both private and public GitHub repositories from initialization.

## Overview

ArgoCD supports both public and private repositories. For private repositories, you can use either:
1. **GitHub Personal Access Token** (recommended for simplicity)
2. **SSH Key** (recommended for security)

The configuration is managed through environment variables in a `.env` file.

## Prerequisites

- GitHub repository (public or private)
- Admin access to the repository (for private repos)
- Terraform configured for your environment

## Quick Setup

### 1. Initialize Environment Configuration

```bash
# Create environment configuration
make setup-env

# Edit .env file with your settings
# For public repos: set REPO_TYPE=public
# For private repos: set REPO_TYPE=private and add credentials
```

### 2. Validate Configuration

```bash
# Validate environment configuration
make validate-env

# Show current configuration
make show-env
```

### 3. Bootstrap Platform

```bash
# Bootstrap with environment configuration
make bootstrap
```

## Detailed Setup Options

### Option 1: GitHub Personal Access Token (Recommended)

#### 1. Create GitHub Personal Access Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Set expiration (recommend 1 year for production)
4. Select scopes:
   - `repo` (Full control of private repositories)
   - `read:org` (Read org and team membership)
5. Generate token and copy it immediately

#### 2. Configure Environment Variables

Edit your `.env` file:

```bash
# Repository configuration
REPO_URL=https://github.com/comind-pro/comind-ops
REPO_TYPE=private

# GitHub credentials
GITHUB_USERNAME=your-github-username
GITHUB_TOKEN=ghp_your_personal_access_token_here
# Leave SSH key empty when using token
GITHUB_SSH_PRIVATE_KEY_PATH=
```

#### 3. Deploy Infrastructure

```bash
# Validate configuration
make validate-env

# Bootstrap platform
make bootstrap
```

### Option 2: SSH Key (More Secure)

#### 1. Generate SSH Key Pair

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "argocd@comind-ops" -f ~/.ssh/argocd_github

# Add to SSH agent
ssh-add ~/.ssh/argocd_github
```

#### 2. Add Public Key to GitHub

1. Copy the public key:
   ```bash
   cat ~/.ssh/argocd_github.pub
   ```

2. Go to [GitHub Settings > SSH and GPG keys](https://github.com/settings/keys)
3. Click "New SSH key"
4. Add the public key with title "ArgoCD - ComindOps Platform"

#### 3. Test SSH Connection

```bash
# Test SSH connection to GitHub
ssh -T git@github.com
# Should return: Hi username! You've successfully authenticated...
```

#### 4. Configure Environment Variables

Edit your `.env` file:

```bash
# Repository configuration
REPO_URL=https://github.com/comind-pro/comind-ops
REPO_TYPE=private

# GitHub credentials (SSH)
GITHUB_USERNAME=  # Leave empty for SSH
GITHUB_TOKEN=     # Leave empty for SSH
GITHUB_SSH_PRIVATE_KEY_PATH=~/.ssh/argocd_github
```

#### 5. Deploy Infrastructure

```bash
# Validate configuration
make validate-env

# Bootstrap platform
make bootstrap
```

## Verification

### 1. Check ArgoCD Repository Connection

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login to ArgoCD UI
argocd login localhost:8080

# List repositories
argocd repo list
```

### 2. Verify Repository Access

```bash
# Check if repository is accessible
argocd repo get https://github.com/comind-pro/comind-ops

# Test repository connection
argocd repo get https://github.com/comind-pro/comind-ops --refresh
```

### 3. Check Application Sync

```bash
# List applications
argocd app list

# Check root application status
argocd app get comind-ops-platform-root

# Force sync if needed
argocd app sync comind-ops-platform-root
```

## Troubleshooting

### Common Issues

#### 1. Repository Connection Failed

**Error**: `repository not accessible`

**Solution**:
- Verify GitHub token has correct scopes
- Check if repository URL is correct
- Ensure token is not expired

```bash
# Check repository secret
kubectl get secret argocd-repo-credentials -n argocd -o yaml

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-repo-server
```

#### 2. SSH Key Issues

**Error**: `Host key verification failed`

**Solution**:
- Verify SSH key is correctly mounted
- Check SSH known hosts configuration
- Test SSH connection manually

```bash
# Check SSH key secret
kubectl get secret argocd-repo-server-ssh-keys -n argocd -o yaml

# Test SSH from within cluster
kubectl exec -n argocd deployment/argocd-repo-server -- ssh -T git@github.com
```

#### 3. Application Sync Issues

**Error**: `application out of sync`

**Solution**:
- Check if root application is properly configured
- Verify k8s/kustomize directory structure
- Check ArgoCD project permissions

```bash
# Check application status
argocd app get comind-ops-platform-root

# Check application events
argocd app get comind-ops-platform-root --events

# Force refresh
argocd app get comind-ops-platform-root --refresh
```

### Debug Commands

```bash
# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server

# Check ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check all ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD secrets
kubectl get secrets -n argocd | grep argocd
```

## Security Best Practices

### 1. Token Management

- Use dedicated service account for ArgoCD
- Rotate tokens regularly (every 6-12 months)
- Use minimal required scopes
- Store tokens in secure secret management

### 2. SSH Key Management

- Use ED25519 keys (more secure than RSA)
- Protect private keys with passphrases
- Rotate keys periodically
- Use separate keys for different environments

### 3. Network Security

- Use HTTPS for all repository access
- Implement network policies
- Monitor repository access logs
- Use private networks where possible

## Environment-Specific Configuration

### Local Development

```bash
# .env.local
REPO_URL=https://github.com/comind-pro/comind-ops
REPO_TYPE=private
GITHUB_USERNAME=dev-user
GITHUB_TOKEN=ghp_dev_token
GITHUB_SSH_PRIVATE_KEY_PATH=
CLUSTER_TYPE=local
ENVIRONMENT=dev
```

### AWS Production

```bash
# .env.prod
REPO_URL=https://github.com/comind-pro/comind-ops
REPO_TYPE=private
GITHUB_USERNAME=prod-bot
GITHUB_TOKEN=ghp_prod_token
GITHUB_SSH_PRIVATE_KEY_PATH=
CLUSTER_TYPE=aws
ENVIRONMENT=prod
AWS_REGION=us-west-2
```

## Automation

### CI/CD Integration

```yaml
# .github/workflows/deploy.yml
- name: Deploy to ArgoCD
  run: |
    # Create environment configuration
    echo "REPO_URL=https://github.com/comind-pro/comind-ops" >> .env
    echo "REPO_TYPE=private" >> .env
    echo "GITHUB_TOKEN=${{ secrets.ARGOCD_GITHUB_TOKEN }}" >> .env
    echo "CLUSTER_TYPE=aws" >> .env
    echo "ENVIRONMENT=prod" >> .env
    
    # Validate and deploy
    make validate-env
    make bootstrap
```

### Secret Management

```bash
# Using external secret management
kubectl create secret generic argocd-repo-credentials \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN \
  -n argocd
```

## Support

For issues with ArgoCD private repository setup:

1. Check [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
2. Review [GitHub API Documentation](https://docs.github.com/en/rest)
3. Check project issues and discussions
4. Contact platform team for assistance
