# Terraform Configuration Examples

This directory contains example `terraform.tfvars` files for different environments and use cases. These files demonstrate how to configure the Terraform modules for various deployment scenarios.

## File Structure

```
infra/terraform/environments/
├── local/
│   ├── terraform.tfvars.example          # Basic local k3d configuration
│   ├── terraform.tfvars.dev.example      # Local development configuration
│   └── terraform.tfvars                  # Current local configuration
├── aws/
│   ├── terraform.tfvars.example          # Basic AWS EKS configuration
│   ├── terraform.tfvars.dev.example      # AWS development environment
│   ├── terraform.tfvars.stage.example    # AWS staging environment
│   ├── terraform.tfvars.prod.example     # AWS production environment
│   └── terraform.tfvars                  # Current AWS configuration
```

## Usage Instructions

### 1. Choose Your Environment

Select the appropriate example file based on your target environment:

- **Local Development**: Use `local/terraform.tfvars.example` or `local/terraform.tfvars.dev.example`
- **AWS Development**: Use `aws/terraform.tfvars.dev.example`
- **AWS Staging**: Use `aws/terraform.tfvars.stage.example`
- **AWS Production**: Use `aws/terraform.tfvars.prod.example`

### 2. Copy and Customize

```bash
# For local development
cp infra/terraform/environments/local/terraform.tfvars.example infra/terraform/environments/local/terraform.tfvars

# For AWS development
cp infra/terraform/environments/aws/terraform.tfvars.dev.example infra/terraform/environments/aws/terraform.tfvars

# For AWS staging
cp infra/terraform/environments/aws/terraform.tfvars.stage.example infra/terraform/environments/aws/terraform.tfvars

# For AWS production
cp infra/terraform/environments/aws/terraform.tfvars.prod.example infra/terraform/environments/aws/terraform.tfvars
```

### 3. Modify Configuration

Edit the `terraform.tfvars` file to match your specific requirements:

- Update cluster names to be unique
- Adjust resource sizes based on your needs
- Configure AWS regions and availability zones
- Set appropriate tags for your organization
- Modify network configurations as needed

### 4. Deploy Infrastructure

```bash
# For local environment
make bootstrap PROFILE=local

# For AWS environment
make bootstrap PROFILE=aws
```

## Configuration Examples

### Local Development

The local configuration uses k3d (Kubernetes in Docker) for local development:

```hcl
# Basic local configuration
cluster_name       = "comind-ops-dev"
cluster_port       = 6443
ingress_http_port  = 8080
ingress_https_port = 8443
environment        = "dev"
```

### AWS Development

The AWS development configuration uses smaller instances and minimal resources:

```hcl
# AWS development configuration
cluster_name = "comind-ops-dev"
environment  = "dev"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.small"
eks_node_desired_size = 1
eks_node_max_size     = 3
eks_node_min_size     = 1
```

### AWS Staging

The AWS staging configuration uses medium instances with moderate resources:

```hcl
# AWS staging configuration
cluster_name = "comind-ops-stage"
environment  = "stage"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.medium"
eks_node_desired_size = 2
eks_node_max_size     = 4
eks_node_min_size     = 1

# Enable multi-AZ deployment
availability_zones = ["us-west-2a", "us-west-2b"]
```

### AWS Production

The AWS production configuration uses large instances with high availability:

```hcl
# AWS production configuration
cluster_name = "comind-ops-prod"
environment  = "prod"
aws_region   = "us-west-2"

eks_node_instance_type = "t3.large"
eks_node_desired_size = 3
eks_node_max_size     = 10
eks_node_min_size     = 3

# Enable multi-AZ deployment
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Enable security features
enable_encryption = true
enable_network_policies = true
```

## Environment-Specific Considerations

### Local Development

- Uses k3d for local Kubernetes cluster
- Minimal resource requirements
- Fast startup and teardown
- Perfect for development and testing

### AWS Development

- Uses smaller EC2 instances (t3.small)
- Minimal node count for cost optimization
- Single availability zone
- Development-specific tags and configurations

### AWS Staging

- Uses medium EC2 instances (t3.medium)
- Moderate node count for testing
- Multi-AZ deployment for reliability testing
- Staging-specific monitoring and logging

### AWS Production

- Uses large EC2 instances (t3.large)
- High node count for availability
- Multi-AZ deployment across all zones
- Production-grade security and monitoring
- Backup and disaster recovery configurations

## Security Considerations

### Production Environment

- Enable encryption at rest and in transit
- Use network policies for pod-to-pod communication
- Enable pod security policies
- Configure proper IAM roles and policies
- Enable audit logging
- Use private subnets for worker nodes

### Development Environment

- Use public subnets for easier access
- Disable strict security policies for development
- Enable debug logging
- Use development-specific tags

## Cost Optimization

### Development

- Use smaller instance types
- Minimal node count
- Single availability zone
- Spot instances (if available)

### Staging

- Use medium instance types
- Moderate node count
- Multi-AZ for testing
- Reserved instances for predictable workloads

### Production

- Use large instance types
- High node count for availability
- Multi-AZ deployment
- Reserved instances for cost savings
- Auto-scaling for dynamic workloads

## Troubleshooting

### Common Issues

1. **Cluster name conflicts**: Ensure cluster names are unique across environments
2. **Resource limits**: Adjust instance types and node counts based on your needs
3. **Network conflicts**: Use different CIDR blocks for different environments
4. **AWS permissions**: Ensure proper IAM permissions for Terraform operations

### Getting Help

- Check the Terraform documentation for variable descriptions
- Review the example files for configuration patterns
- Use `terraform plan` to validate configurations before applying
- Check the Makefile for available commands and options

## Next Steps

After configuring your environment:

1. Run `make bootstrap` to deploy the infrastructure
2. Verify the deployment with `kubectl get nodes`
3. Deploy applications using the app scaffolding tools
4. Monitor the environment using the provided monitoring tools
5. Set up CI/CD pipelines for automated deployments
