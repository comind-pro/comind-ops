#!/bin/bash
set -euo pipefail

# Comind-Ops Platform - Terraform Management Script
# Usage: ./infra/terraform/scripts/tf.sh <environment> [app-name] [command] [options]

# Check for help first
if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    print_usage() {
        cat << EOF
Usage: $0 <environment> [app-name] [command] [options]

Arguments:
    environment     Target environment (dev, stage, prod)
    app-name        Application name or 'core' for infrastructure (default: core)
    command         Terraform command (plan, apply, destroy, output, etc.) (default: plan)

Options:
    --help          Show this help message
    --auto-approve  Auto approve for apply/destroy commands
    --var key=value Set Terraform variable
    --workspace WS  Terraform workspace (default: environment name)
    --profile PROF  Infrastructure profile (local, aws) (default: local)

Examples:
    $0 dev core plan --profile local       # Plan local infrastructure for dev
    $0 dev core apply --profile aws        # Apply AWS infrastructure  
    $0 dev my-app plan                      # Plan app infrastructure
    $0 prod my-app apply --auto-approve
    $0 dev my-app output                    # Show outputs
EOF
    }
    print_usage
    exit 0
fi

ENVIRONMENT="${1:-}"
APP_NAME="${2:-core}"
COMMAND="${3:-plan}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_usage() {
    cat << EOF
Usage: $0 <environment> [app-name] [command] [options]

Arguments:
    environment     Target environment (dev, stage, prod)
    app-name        Application name or 'core' for infrastructure (default: core)
    command         Terraform command (plan, apply, destroy, output, etc.) (default: plan)

Options:
    --help          Show this help message
    --auto-approve  Auto-approve terraform apply/destroy
    --var-file FILE Use specific tfvars file
    --target RES    Target specific resource
    --workspace WS  Use specific terraform workspace
    --profile PROF  Infrastructure profile (local, aws) (default: local)

Examples:
    $0 dev core plan --profile local       # Plan local core infrastructure for dev
    $0 dev core apply --profile aws        # Apply AWS core infrastructure for dev  
    $0 dev my-app plan                      # Plan app-specific resources
    $0 dev my-app apply --auto-approve      # Apply with auto-approval
    $0 prod my-app destroy                  # Destroy app resources in prod

Terraform Directories:
    Core (Local): infra/terraform/environments/local/
    Core (AWS):   infra/terraform/environments/aws/
    Apps:         k8s/apps/<app-name>/terraform/
    Envs:         infra/terraform/envs/<env>/platform/
EOF
}

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default values
AUTO_APPROVE=false
VAR_FILE=""
TARGET=""
WORKSPACE=""
PROFILE="local"

# Parse command line arguments
shift 3 # Remove positional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) print_usage; exit 0 ;;
        --auto-approve) AUTO_APPROVE=true; shift ;;
        --var-file) VAR_FILE="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --workspace) WORKSPACE="$2"; shift 2 ;;
        --profile) PROFILE="$2"; shift 2 ;;
        *) error "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done


# Validation  
if [[ -z "$ENVIRONMENT" ]]; then
    error "Environment is required"
    print_usage
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    error "Environment must be one of: dev, stage, prod"
    exit 1
fi

if [[ ! "$PROFILE" =~ ^(local|aws)$ ]]; then
    error "Profile must be one of: local, aws"
    exit 1
fi

# Determine Terraform directory
if [[ "$APP_NAME" == "core" ]]; then
    # Use new environments structure for core infrastructure
    TF_DIR="$PROJECT_ROOT/infra/terraform/environments/$PROFILE"
    if [[ ! -d "$TF_DIR" ]]; then
        error "Terraform environment directory not found: $TF_DIR"
        error "Available profiles: local, aws"
        exit 1
    fi
elif [[ -d "$PROJECT_ROOT/k8s/apps/$APP_NAME/terraform" ]]; then
    TF_DIR="$PROJECT_ROOT/k8s/apps/$APP_NAME/terraform"
elif [[ -d "$PROJECT_ROOT/infra/terraform/envs/$ENVIRONMENT/$APP_NAME" ]]; then
    TF_DIR="$PROJECT_ROOT/infra/terraform/envs/$ENVIRONMENT/$APP_NAME"
else
    error "Terraform directory not found for app: $APP_NAME"
    exit 1
fi

# Check dependencies
if ! command -v terraform &> /dev/null; then
    error "terraform is not installed or not in PATH"
    exit 1
fi

log "Running Terraform $COMMAND for $APP_NAME in $ENVIRONMENT [$PROFILE profile]"
log "Directory: $TF_DIR"

# Change to terraform directory and run
cd "$TF_DIR"

# Set environment variables
export TF_VAR_environment="$ENVIRONMENT"
export TF_VAR_app_name="$APP_NAME"
# For core infrastructure, the profile determines the directory
# App-specific terraform may still need cluster_type
if [[ "$APP_NAME" != "core" ]]; then
    export TF_VAR_cluster_type="$PROFILE"
fi

# Set workspace
if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE="$ENVIRONMENT"
fi

# Configure providers based on profile (for app terraform)
if [[ "$APP_NAME" != "core" ]]; then
    log "Configuring providers for $PROFILE profile..."
    
    if [[ "$PROFILE" == "local" ]]; then
        cat > "providers_override.tf" << 'EOF'
# Provider override for local k3d environment
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-comind-ops-dev"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "k3d-comind-ops-dev"
  }
}

# AWS provider with mock credentials (required by modules)
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock"
}

provider "digitalocean" {
  # Mock token for local development  
  token = "mock"
}
EOF
    elif [[ "$PROFILE" == "aws" ]]; then
        cat > "providers_override.tf" << 'EOF'
# Provider override for AWS environment
# Note: For production AWS deployments, configure these providers
# based on your specific EKS cluster configuration

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context_cluster = "your-aws-eks-cluster"
  # Alternatively, use exec authentication:
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   command     = "aws"
  #   args        = ["eks", "get-token", "--cluster-name", "your-cluster-name"]
  # }
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context_cluster = "your-aws-eks-cluster"
  }
}

# AWS provider - uses AWS credentials from environment/profile
provider "aws" {
  region = "us-east-1"
}

# DigitalOcean provider (optional)
provider "digitalocean" {
  token = "your-do-token-here"
}
EOF
    fi
fi

# Initialize if needed
if [[ ! -d ".terraform" ]]; then
    log "Initializing Terraform..."
    terraform init
fi

# Build terraform args
TF_ARGS=()
if [[ -n "$VAR_FILE" ]]; then
    TF_ARGS+=("-var-file=$VAR_FILE")
fi
if [[ -n "$TARGET" ]]; then
    TF_ARGS+=("-target=$TARGET")
fi
if [[ "$AUTO_APPROVE" == "true" && ("$COMMAND" == "apply" || "$COMMAND" == "destroy") ]]; then
    TF_ARGS+=("-auto-approve")
fi

# Select workspace
if terraform workspace list | grep -q "$WORKSPACE"; then
    terraform workspace select "$WORKSPACE"
else
    terraform workspace new "$WORKSPACE"
fi

# Execute terraform command
case "$COMMAND" in
    "apply")
        if [[ "$AUTO_APPROVE" != "true" ]]; then
            warning "This will apply changes to $ENVIRONMENT environment"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Aborted by user"
                exit 0
            fi
        fi
        terraform apply "${TF_ARGS[@]:+${TF_ARGS[@]}}"
        success "✅ Terraform apply completed!"
        ;;
    "destroy")
        warning "This will DESTROY resources in $ENVIRONMENT environment!"
        if [[ "$AUTO_APPROVE" != "true" ]]; then
            read -p "Type 'destroy' to confirm: " -r
            if [[ "$REPLY" != "destroy" ]]; then
                log "Aborted by user"
                exit 0
            fi
        fi
        terraform destroy "${TF_ARGS[@]:+${TF_ARGS[@]}}"
        success "✅ Terraform destroy completed!"
        ;;
    *)
        terraform "$COMMAND" "${TF_ARGS[@]:+${TF_ARGS[@]}}"
        ;;
esac

success "Terraform operation completed! 🚀"