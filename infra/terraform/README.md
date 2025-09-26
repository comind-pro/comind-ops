# Terraform Infrastructure

This directory contains the Terraform configurations for the Comind-Ops Platform infrastructure.

## Directory Structure

```
terraform/
├── environments/           # Environment-specific configurations
│   ├── local/             # Local development (k3d cluster)
│   │   ├── main.tf        # Local infrastructure resources
│   │   ├── providers.tf   # Local providers configuration
│   │   ├── variables.tf   # Local variables
│   │   ├── outputs.tf     # Local outputs
│   │   └── terraform.tfvars # Local default values
│   ├── aws/               # AWS production (EKS cluster)
│   │   ├── main.tf        # AWS infrastructure resources
│   │   ├── providers.tf   # AWS providers configuration
│   │   ├── variables.tf   # AWS variables
│   │   ├── outputs.tf     # AWS outputs
│   │   └── terraform.tfvars # AWS default values
│   └── azure/             # Azure (future)
├── modules/               # Reusable terraform modules
├── envs/                  # Legacy environment configs
└── apps/                  # App-specific infrastructure
```

## Usage

### Local Development
```bash
# Using make commands
make bootstrap PROFILE=local       # Default profile
make bootstrap                     # Same as above

# Using tf.sh directly
./infra/terraform/scripts/tf.sh dev core plan --profile local
./infra/terraform/scripts/tf.sh dev core apply --profile local
```

### AWS Production  
```bash
# Using make commands
make bootstrap PROFILE=aws

# Using tf.sh directly  
./infra/terraform/scripts/tf.sh dev core plan --profile aws
./infra/terraform/scripts/tf.sh dev core apply --profile aws
```

## Environment Details

### Local Profile (`environments/local/`)
- **Infrastructure**: k3d Kubernetes cluster
- **Load Balancer**: MetalLB for local services
- **Ingress**: Nginx Ingress Controller
- **External Services**: Docker Compose (PostgreSQL, MinIO)
- **ArgoCD**: Accessible via http://argocd.dev.127.0.0.1.nip.io:8080

### AWS Profile (`environments/aws/`)
- **Infrastructure**: EKS cluster with VPC, subnets, NAT gateways
- **Load Balancer**: AWS Load Balancer Controller
- **Ingress**: AWS ALB/NLB integration  
- **External Services**: RDS, S3 (configured separately)
- **ArgoCD**: Accessible via AWS LoadBalancer

## Configuration

Each environment has its own `terraform.tfvars` with sensible defaults:

### Local Configuration
- `cluster_name = "comind-ops-dev"`
- `ingress_http_port = 8080`
- `ingress_https_port = 8443`

### AWS Configuration  
- `aws_region = "us-west-2"`
- `eks_cluster_version = "1.28"`
- `eks_node_instance_type = "t3.medium"`
- `vpc_cidr = "10.0.0.0/16"`

## Migration from Legacy

The old `core/` directory has been moved to `core.backup/` and replaced with the new environment-specific structure. This provides:

- ✅ **Cleaner separation** - No conditional logic
- ✅ **Better maintainability** - Environment-specific configurations
- ✅ **Easier extension** - Add new environments easily
- ✅ **Standard practices** - Follows Terraform community conventions

## Commands Reference

All existing make commands work with the new structure:

```bash
make bootstrap PROFILE=local|aws    # Deploy infrastructure
make cleanup PROFILE=local|aws      # Destroy infrastructure
make validate PROFILE=local|aws     # Validate configurations
make lint PROFILE=local|aws         # Format and lint code
```
