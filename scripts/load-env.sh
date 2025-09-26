#!/bin/bash

# Load environment variables from .env file
# This script is sourced by other scripts to load configuration

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load common functions
source "$SCRIPT_DIR/common.sh"

# Environment file path
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    error ".env file not found at $ENV_FILE"
    echo "Run 'scripts/setup-env.sh init' to create the environment configuration"
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

# Validate required variables
validate_required_vars() {
    local required_vars=(
        "REPO_URL"
        "REPO_TYPE"
        "ENVIRONMENT"
        "CLUSTER_TYPE"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo "Run 'scripts/setup-env.sh validate' to check your configuration"
        exit 1
    fi
}

# Export Terraform variables
export_terraform_vars() {
    # Repository configuration
    export TF_VAR_repo_url="$REPO_URL"
    export TF_VAR_repo_type="$REPO_TYPE"
    
    # Environment configuration
    export TF_VAR_environment="$ENVIRONMENT"
    export TF_VAR_cluster_type="$CLUSTER_TYPE"
    
    # GitHub credentials (for private repos)
    if [[ "$REPO_TYPE" == "private" ]]; then
        if [[ -n "${GITHUB_USERNAME:-}" ]]; then
            export TF_VAR_github_username="$GITHUB_USERNAME"
        fi
        
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            export TF_VAR_github_token="$GITHUB_TOKEN"
        fi
        
        if [[ -n "${GITHUB_SSH_PRIVATE_KEY_PATH:-}" && -f "${GITHUB_SSH_PRIVATE_KEY_PATH}" ]]; then
            export TF_VAR_github_ssh_private_key="$(cat "$GITHUB_SSH_PRIVATE_KEY_PATH")"
        fi
    fi
    
    # AWS configuration
    if [[ "$CLUSTER_TYPE" == "aws" ]]; then
        export TF_VAR_aws_region="${AWS_REGION:-us-west-2}"
        export TF_VAR_eks_cluster_version="${EKS_CLUSTER_VERSION:-1.28}"
        export TF_VAR_eks_node_instance_type="${EKS_NODE_INSTANCE_TYPE:-t3.medium}"
        export TF_VAR_eks_node_desired_size="${EKS_NODE_DESIRED_SIZE:-2}"
        export TF_VAR_eks_node_max_size="${EKS_NODE_MAX_SIZE:-4}"
        export TF_VAR_eks_node_min_size="${EKS_NODE_MIN_SIZE:-1}"
    fi
    
    # Local configuration
    if [[ "$CLUSTER_TYPE" == "local" ]]; then
        export TF_VAR_k3d_cluster_name="${K3D_CLUSTER_NAME:-comind-ops-dev}"
        export TF_VAR_k3d_cluster_port="${K3D_CLUSTER_PORT:-6443}"
        export TF_VAR_k3d_http_port="${K3D_HTTP_PORT:-8080}"
        export TF_VAR_k3d_https_port="${K3D_HTTPS_PORT:-8443}"
    fi
}

# Main function
main() {
    local validate="${1:-true}"
    
    if [[ "$validate" == "true" ]]; then
        validate_required_vars
    fi
    
    export_terraform_vars
    
    if [[ "${DEV_MODE:-false}" == "true" ]]; then
        debug "Environment variables loaded from $ENV_FILE"
        debug "Repository: $REPO_URL ($REPO_TYPE)"
        debug "Environment: $ENVIRONMENT ($CLUSTER_TYPE)"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
