# Infrastructure

This directory contains all infrastructure-related components for the Comind-Ops Platform.

## Structure

```
infra/
├── docker/                    # External services (PostgreSQL, MinIO)
│   ├── docker-compose.yml     # Docker Compose configuration
│   ├── env.template           # Environment variables template
│   ├── postgres/              # PostgreSQL configuration
│   │   ├── init/              # Database initialization scripts
│   │   └── config/            # PostgreSQL configuration files
│   └── scripts/               # Backup and maintenance scripts
│       ├── backup-postgres.sh # PostgreSQL backup automation
│       └── backup-minio.sh    # MinIO backup automation
│
└── terraform/                 # Infrastructure as Code
    ├── core/                  # Core cluster infrastructure
    ├── modules/               # Reusable Terraform modules
    │   └── app_skel/          # Application infrastructure template
    └── envs/                  # Environment-specific configurations
        └── dev/platform/      # Development platform configuration
```

## External Services (Docker)

The `docker/` directory contains Docker Compose configurations for external data services that run outside the Kubernetes cluster:

### PostgreSQL Database
- **Purpose**: Primary database for all platform applications
- **Configuration**: Multi-database setup with optimized settings
- **Backups**: Automated daily backups with retention policies
- **Access**: `localhost:5432` from the host machine

### MinIO Object Storage
- **Purpose**: S3-compatible object storage for applications
- **Configuration**: Multiple buckets with lifecycle policies
- **Backups**: Automated mirroring and compression
- **Access**: API at `localhost:9000`, Console at `localhost:9001`

### Management Commands
```bash
# Start external services
make services-start

# Check service status
make services-status

# View service logs
make services-logs

# Create backups
make services-backup

# Complete setup (first time)
make services-setup
```

## Terraform Infrastructure

The `terraform/` directory contains Infrastructure as Code configurations:

### Core Infrastructure (`terraform/core/`)
- k3d Kubernetes cluster
- MetalLB load balancer
- Ingress-Nginx controller
- ArgoCD GitOps platform
- Sealed Secrets controller

### Application Skeleton Module (`terraform/modules/app_skel/`)
- Database provisioning
- Storage buckets
- Queue configuration
- Cache setup
- Networking and security
- Monitoring integration

### Environment Configurations (`terraform/envs/`)
- Environment-specific settings
- Resource sizing and limits
- Cloud provider configurations
- Multi-environment deployments

## Usage

### Initial Setup
```bash
# Bootstrap entire infrastructure
make bootstrap

# This will:
# 1. Start external services (PostgreSQL, MinIO)
# 2. Create k3d cluster
# 3. Deploy core platform components
# 4. Apply base Kubernetes resources
# 5. Deploy platform services
```

### Managing External Services
```bash
# Service lifecycle
./scripts/external-services.sh start
./scripts/external-services.sh stop  
./scripts/external-services.sh restart

# Monitoring and maintenance
./scripts/external-services.sh status
./scripts/external-services.sh logs --follow
./scripts/external-services.sh backup

# Setup and cleanup
./scripts/external-services.sh setup
./scripts/external-services.sh clean
```

### Terraform Operations
```bash
# Core infrastructure
./scripts/tf.sh dev core plan
./scripts/tf.sh dev core apply

# Application infrastructure
make tf-plan-app APP=my-app
make tf-apply-app APP=my-app
make tf-destroy-app APP=my-app
```

## Benefits of This Architecture

### External Services
- **Data Persistence**: Services survive cluster recreation
- **Performance**: Optimized configurations without Kubernetes overhead
- **Management**: Direct access for debugging and administration
- **Reliability**: Dedicated network and health monitoring

### Infrastructure as Code
- **Consistency**: Reproducible infrastructure across environments
- **Version Control**: All infrastructure changes tracked in Git
- **Automation**: Fully automated provisioning and updates
- **Scalability**: Easy to extend and modify for new requirements

This infrastructure setup provides a robust foundation for the Comind-Ops Platform, combining the benefits of containerized data services with cloud-native Kubernetes applications.
