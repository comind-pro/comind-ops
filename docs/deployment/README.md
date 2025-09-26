# Local Environment Terraform Configuration

This directory contains Terraform configuration for the local development environment using k3d.

## Usage

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply

# Destroy resources
terraform destroy
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the k3d cluster | `string` | `"comind-ops"` | no |
| cluster_type | Type of cluster (local, aws) | `string` | `"local"` | no |
| environment | Environment name | `string` | `"dev"` | no |
| github_token | GitHub personal access token for private repository access | `string` | n/a | yes |
| github_username | GitHub username for repository access | `string` | n/a | yes |
| repo_url | Repository URL for ArgoCD | `string` | `"https://github.com/comind-pro/comind-ops"` | no |

## Outputs

| Name | Description |
|------|-------------|
| argocd_credentials | ArgoCD admin credentials |
| cluster_endpoint | Kubernetes cluster endpoint |
| created_namespaces | List of created Kubernetes namespaces |

## Resources

This configuration creates:

- k3d Kubernetes cluster
- MetalLB load balancer
- Nginx Ingress Controller  
- Sealed Secrets Controller
- ArgoCD for GitOps
- Required Kubernetes namespaces
- External services (PostgreSQL, MinIO) via Docker Compose

## Dependencies

- k3d
- kubectl
- helm
- docker
- docker-compose
