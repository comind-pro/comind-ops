#!/bin/bash
set -euo pipefail

# Comind-Ops Platform - New Application Scaffolding Script
# Usage: ./scripts/new-app.sh <app-name> [options]

# Define print_usage function first
print_usage() {
    cat << EOF
Usage: $0 <app-name> [options]

Options:
    --team TEAM              Team responsible for the app (default: platform)
    --description DESC       Application description
    --port PORT              Service port (default: 8080)
    --sync-wave WAVE         ArgoCD sync wave (default: 10)
    --language LANG          Application language (generic|node|python|go|java)
    --profile PROFILE        Infrastructure profile: local, aws (default: local)
    --with-database          Include database configuration
    --with-cache             Include Redis cache configuration  
    --with-queue             Include queue (ElasticMQ) configuration
    --with-terraform         Generate Terraform infrastructure configuration
    --help                   Show this help message

Examples:
    $0 my-api --team backend --port 3000 --with-database --with-terraform
    $0 my-api --team backend --profile aws --with-database --with-terraform
    $0 my-frontend --team frontend --language node --port 3000 --profile local
    $0 my-worker --team backend --with-queue --sync-wave 20 --with-terraform --profile aws
EOF
}

# Check if app name provided
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    print_usage
    exit 0
fi

APP_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_ROOT/k8s/apps/$APP_NAME"

# Default values
TEAM="${TEAM:-platform}"
DESCRIPTION="${DESCRIPTION:-"Generated application for $APP_NAME"}"
PORT="${PORT:-8080}"
SYNC_WAVE="${SYNC_WAVE:-10}"
LANGUAGE="${LANGUAGE:-generic}"
PROFILE="${PROFILE:-local}"
DATABASE="${DATABASE:-false}"
CACHE="${CACHE:-false}"
QUEUE="${QUEUE:-false}"
WITH_TERRAFORM="${WITH_TERRAFORM:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    cat << EOF
Usage: $0 <app-name> [options]

Options:
    --team TEAM              Team responsible for the app (default: platform)
    --description DESC       Application description
    --port PORT              Service port (default: 8080)
    --sync-wave WAVE         ArgoCD sync wave (default: 10)
    --language LANG          Application language (generic|node|python|go|java)
    --profile PROFILE        Infrastructure profile: local, aws (default: local)
    --with-database          Include database configuration
    --with-cache             Include Redis cache configuration  
    --with-queue             Include queue (ElasticMQ) configuration
    --with-terraform         Generate Terraform infrastructure configuration
    --help                   Show this help message

Examples:
    $0 my-api --team backend --port 3000 --with-database --with-terraform
    $0 my-api --team backend --profile aws --with-database --with-terraform
    $0 my-frontend --team frontend --language node --port 3000 --profile local
    $0 my-worker --team backend --with-queue --sync-wave 20 --with-terraform --profile aws
EOF
}

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Parse command line arguments
while [[ $# -gt 1 ]]; do
    case $2 in
        --team) TEAM="$3"; shift 2 ;;
        --description) DESCRIPTION="$3"; shift 2 ;;
        --port) PORT="$3"; shift 2 ;;
        --sync-wave) SYNC_WAVE="$3"; shift 2 ;;
        --language) LANGUAGE="$3"; shift 2 ;;
        --profile) PROFILE="$3"; shift 2 ;;
        --with-database) DATABASE=true; shift ;;
        --with-cache) CACHE=true; shift ;;
        --with-queue) QUEUE=true; shift ;;
        --with-terraform) WITH_TERRAFORM=true; shift ;;
        --help) print_usage; exit 0 ;;
        *) error "Unknown option: $2"; print_usage; exit 1 ;;
    esac
done

# Validation
if [[ -z "${APP_NAME:-}" ]]; then
    error "App name is required"
    print_usage
    exit 1
fi

if [[ ! "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    error "App name must contain only lowercase letters, numbers, and hyphens"
    exit 1
fi

if [[ -d "$APP_DIR" ]]; then
    error "Application directory already exists: $APP_DIR"
    exit 1
fi

# Validate profile parameter
if [[ "$PROFILE" != "local" && "$PROFILE" != "aws" ]]; then
    error "Invalid profile: $PROFILE. Must be 'local' or 'aws'"
    exit 1
fi

log "Creating new application: $APP_NAME"
log "Team: $TEAM, Port: $PORT, Language: $LANGUAGE, Profile: $PROFILE"
if [[ "$WITH_TERRAFORM" == "true" ]]; then
    log "Features: Database=$DATABASE, Cache=$CACHE, Queue=$QUEUE, Terraform=enabled"
else
    log "Features: Database=$DATABASE, Cache=$CACHE, Queue=$QUEUE"
fi

# Create directory structure
mkdir -p "$APP_DIR"/{chart/templates,values,secrets}
if [[ "$WITH_TERRAFORM" == "true" ]]; then
    mkdir -p "infra/terraform/apps/$APP_NAME"
fi

# Create Helm Chart.yaml
cat > "$APP_DIR/chart/Chart.yaml" << EOF
apiVersion: v2
name: $APP_NAME
description: $DESCRIPTION
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: $TEAM
keywords:
  - $APP_NAME
  - $TEAM
  - comind-ops-platform
EOF

# Add the create_terraform_config function
create_terraform_config() {
    log "🏗️ Creating Terraform infrastructure configuration..."
    
    local terraform_dir="k8s/apps/${APP_NAME}/terraform"
    local terraform_file="${terraform_dir}/main.tf"
    
    mkdir -p "$terraform_dir"
    
    # Generate main.tf with app_skel module
    cat > "$terraform_file" << TF_EOF
# Terraform configuration for ${APP_NAME} application infrastructure
# Profile-agnostic configuration - use with tf.sh script to specify profile

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"  
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Note: Provider configurations are handled by tf.sh script based on selected profile
# For local profile: Uses k3d cluster context and mock AWS credentials
# For AWS profile: Uses real AWS credentials and EKS cluster context

# Development environment module
module "${APP_NAME}_dev" {
  source = "../../../../infra/terraform/modules/app_skel"
  
  # Basic configuration
  app_name     = "${APP_NAME}"
  environment  = "dev"
  team         = "${TEAM}"
  cluster_type = var.cluster_type
  
  # Database configuration
  database = {
    enabled             = ${DATABASE}
    local_storage_size  = ${DATABASE} ? "10Gi" : null
    local_replica_count = ${DATABASE} ? 1 : null
  }
  
  # Storage configuration
  storage = {
    enabled            = true
    local_storage_size = "20Gi"
    buckets = [
      {
        name               = "uploads"
        versioning_enabled = true
        lifecycle_enabled  = false
        cors_enabled       = true
        public_read        = false
      }
    ]
  }
  
  # Queue configuration
  queue = {
    enabled = ${QUEUE}
    queues = ${QUEUE} ? [
      {
        name                        = "default"
        delay_seconds              = 0
        visibility_timeout_seconds = 30
        dlq_enabled               = true
        dlq_max_receive_count     = 3
      }
    ] : []
  }
  
  # Cache configuration
  cache = {
    enabled             = ${CACHE}
    local_storage_size  = ${CACHE} ? "5Gi" : null
    local_replica_count = ${CACHE} ? 1 : null
  }
  
  # Networking configuration
  networking = {
    ingress_enabled     = true
    local_domain        = "127.0.0.1.nip.io"
    local_ingress_class = "nginx"
  }
  
  # Monitoring configuration
  monitoring = {
    enabled            = true
    prometheus_enabled = var.cluster_type == "aws"  # Only enabled for AWS (has Prometheus operator)
    grafana_enabled    = var.cluster_type == "aws"  # Only enabled for AWS
    alerting_enabled   = var.cluster_type == "aws"  # Only enabled for AWS
  }
  
  # Security configuration
  security = {
    create_service_account = true
    create_rbac           = true
    namespace_isolation   = true
  }
  
  # Backup configuration
  backup = {
    enabled                 = ${DATABASE}
    backup_schedule        = "0 2 * * *"
    retention_days         = 7
    database_backup_enabled = ${DATABASE}
    storage_backup_enabled = false
  }
  
  tags = {
    Environment = "development"
    Project     = "comind-ops"
    Team        = "${TEAM}"
    Application = "${APP_NAME}"
    CreatedBy   = "new-app-script"
    Language    = "${LANGUAGE}"
  }
}

# Variables
variable "cluster_type" {
  description = "Type of cluster (local or aws)"
  type        = string
  default     = "${PROFILE}"
}

# Outputs
output "${APP_NAME}_dev_info" {
  description = "${APP_NAME} development environment information"
  value = {
    namespace        = module.${APP_NAME}_dev.namespace
    app_url          = var.cluster_type == "local" ? "http://${APP_NAME}.dev.127.0.0.1.nip.io:${PORT}" : "https://${APP_NAME}.dev.your-domain.com"
    enabled_features = module.${APP_NAME}_dev.enabled_features
  }
}

output "${APP_NAME}_connection_strings" {
  description = "Connection strings for ${APP_NAME} services"
  value       = module.${APP_NAME}_dev.service_endpoints
  sensitive   = true
}
TF_EOF

    # Generate README for the Terraform configuration
    cat > "${terraform_dir}/README.md" << README_EOF
# ${APP_NAME} Infrastructure

Terraform configuration for provisioning infrastructure for the ${APP_NAME} application.
Generated for profile: **${PROFILE}** (can be changed at runtime)

## Usage

### Local Development (k3d)
\`\`\`bash
# Using make commands (recommended)
make tf-init-app APP=${APP_NAME}
make tf-apply-app APP=${APP_NAME} PROFILE=local

# Or using tf.sh directly
./infra/terraform/scripts/tf.sh dev ${APP_NAME} init --profile local
./infra/terraform/scripts/tf.sh dev ${APP_NAME} apply --profile local

# Get application information
make tf-output APP=${APP_NAME} PROFILE=local
\`\`\`

### AWS Production (EKS)
\`\`\`bash
# Using make commands (recommended)
make tf-init-app APP=${APP_NAME} PROFILE=aws
make tf-apply-app APP=${APP_NAME} PROFILE=aws

# Or using tf.sh directly
./infra/terraform/scripts/tf.sh dev ${APP_NAME} init --profile aws
./infra/terraform/scripts/tf.sh dev ${APP_NAME} apply --profile aws

# Get application information
make tf-output APP=${APP_NAME} PROFILE=aws
\`\`\`

## Access URLs

- **Local**: http://${APP_NAME}.dev.127.0.0.1.nip.io:${PORT}
- **AWS**: https://${APP_NAME}.dev.your-domain.com

## Features

This configuration provisions:
- Kubernetes namespace and RBAC
- Resource quotas and limits
- Network policies for security
- Integration with platform services
- Profile-specific monitoring (Prometheus for AWS only)

## Generated Configuration

- **Team**: ${TEAM}
- **Language**: ${LANGUAGE}
- **Default Profile**: ${PROFILE}
- **Features**: Database=${DATABASE}, Cache=${CACHE}, Queue=${QUEUE}
README_EOF

    success "✅ Terraform configuration created at $terraform_dir"
    log "📁 Files created:"
    log "  - $terraform_file"
    log "  - ${terraform_dir}/README.md"
}

# Generate Terraform configuration if requested
if [[ "$WITH_TERRAFORM" == "true" ]]; then
    create_terraform_config
fi

success "✅ Application '$APP_NAME' scaffolded successfully!"
log "Generated structure at: $APP_DIR"
log "Next steps:"
log "  1. Customize templates and values"
log "  2. Create secrets with seal-secret.sh"
if [[ "$WITH_TERRAFORM" == "true" ]]; then
    log "  3. Provision infrastructure: cd k8s/apps/$APP_NAME/terraform && terraform apply"
    log "  4. Build and deploy your application"
else
    log "  3. Build and deploy your application"
fi