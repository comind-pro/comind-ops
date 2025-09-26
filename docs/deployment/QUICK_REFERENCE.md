# Quick Reference: Terraform Configuration Examples

## Local Development (k3d)

```bash
# Copy example configuration
cp infra/terraform/environments/local/terraform.tfvars.example infra/terraform/environments/local/terraform.tfvars

# Deploy local environment
make bootstrap PROFILE=local
```

**Key Configuration:**
```hcl
cluster_name       = "comind-ops-dev"
cluster_port       = 6443
ingress_http_port  = 8080
ingress_https_port = 8443
environment        = "dev"
```

## AWS Development

```bash
# Copy example configuration
cp infra/terraform/environments/aws/terraform.tfvars.dev.example infra/terraform/environments/aws/terraform.tfvars

# Deploy AWS development environment
make bootstrap PROFILE=aws
```

**Key Configuration:**
```hcl
cluster_name = "comind-ops-dev"
environment  = "dev"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.small"
eks_node_desired_size = 1
eks_node_max_size     = 3
eks_node_min_size     = 1
```

## AWS Staging

```bash
# Copy example configuration
cp infra/terraform/environments/aws/terraform.tfvars.stage.example infra/terraform/environments/aws/terraform.tfvars

# Deploy AWS staging environment
make bootstrap PROFILE=aws
```

**Key Configuration:**
```hcl
cluster_name = "comind-ops-stage"
environment  = "stage"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.medium"
eks_node_desired_size = 2
eks_node_max_size     = 4
eks_node_min_size     = 1

availability_zones = ["us-west-2a", "us-west-2b"]
```

## AWS Production

```bash
# Copy example configuration
cp infra/terraform/environments/aws/terraform.tfvars.prod.example infra/terraform/environments/aws/terraform.tfvars

# Deploy AWS production environment
make bootstrap PROFILE=aws
```

**Key Configuration:**
```hcl
cluster_name = "comind-ops-prod"
environment  = "prod"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.large"
eks_node_desired_size = 3
eks_node_max_size     = 10
eks_node_min_size     = 3

availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
enable_encryption = true
enable_network_policies = true
```

## Common Commands

```bash
# Initialize Terraform
make tf-init PROFILE=local
make tf-init PROFILE=aws

# Plan changes
make tf-plan PROFILE=local
make tf-plan PROFILE=aws

# Apply changes
make tf-apply PROFILE=local
make tf-apply PROFILE=aws

# Destroy infrastructure
make tf-destroy PROFILE=local
make tf-destroy PROFILE=aws

# Validate configuration
make validate PROFILE=local
make validate PROFILE=aws

# Lint configuration
make lint PROFILE=local
make lint PROFILE=aws
```

## Environment Variables

### AWS Configuration

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"

# Or use AWS CLI
aws configure
```

### Local Development

```bash
# No additional environment variables needed for local development
# k3d will handle Docker networking automatically
```

## Troubleshooting

### Common Issues

1. **Cluster name conflicts**: Use unique names for each environment
2. **Resource limits**: Adjust instance types based on your needs
3. **Network conflicts**: Use different CIDR blocks for different environments
4. **AWS permissions**: Ensure proper IAM permissions

### Useful Commands

```bash
# Check cluster status
kubectl get nodes

# Check cluster info
kubectl cluster-info

# Check AWS EKS cluster
aws eks describe-cluster --name comind-ops-dev --region us-west-2

# Update kubeconfig for AWS
aws eks update-kubeconfig --region us-west-2 --name comind-ops-dev
```

## Cost Estimation

### Local Development
- **Cost**: Free (uses local Docker)
- **Resources**: Minimal CPU/Memory usage

### AWS Development
- **Cost**: ~$50-100/month
- **Resources**: 1x t3.small instance

### AWS Staging
- **Cost**: ~$200-400/month
- **Resources**: 2x t3.medium instances

### AWS Production
- **Cost**: ~$500-1000/month
- **Resources**: 3x t3.large instances + load balancers + storage
