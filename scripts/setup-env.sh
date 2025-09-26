#!/bin/bash

# ComindOps Platform Environment Setup Script
# This script helps configure the environment before running bootstrap

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load common functions
source "$SCRIPT_DIR/common.sh"

# Configuration
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/env.example"

print_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init        Initialize environment configuration
    validate    Validate current environment configuration
    show        Show current environment configuration (without secrets)
    help        Show this help message

Options:
    -f, --force    Force overwrite existing .env file
    -q, --quiet    Quiet mode (minimal output)

Examples:
    $0 init                    # Interactive setup
    $0 init --force           # Force overwrite existing .env
    $0 validate               # Validate configuration
    $0 show                   # Show current config

EOF
}

# Check if .env file exists
check_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        return 0
    else
        return 1
    fi
}

# Initialize environment configuration
init_env() {
    local force=false
    local quiet=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Check if .env already exists
    if check_env_file && [[ "$force" != "true" ]]; then
        if [[ "$quiet" != "true" ]]; then
            warning ".env file already exists at $ENV_FILE"
            echo "Use --force to overwrite or edit manually"
        fi
        return 0
    fi
    
    # Copy example file
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        error "Example environment file not found: $ENV_EXAMPLE"
        exit 1
    fi
    
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    success "Created .env file from example"
    
    if [[ "$quiet" != "true" ]]; then
        echo
        info "Environment file created at: $ENV_FILE"
        echo "Please edit the file and configure your settings:"
        echo "  - Repository URL and type"
        echo "  - GitHub credentials (for private repos)"
        echo "  - Environment-specific settings"
        echo
        echo "Then run: $0 validate"
    fi
}

# Validate environment configuration
validate_env() {
    if ! check_env_file; then
        error ".env file not found. Run '$0 init' first"
        exit 1
    fi
    
    # Source the environment file
    set -a
    source "$ENV_FILE"
    set +a
    
    local errors=0
    
    # Validate required variables
    local required_vars=(
        "REPO_URL"
        "REPO_TYPE"
        "ENVIRONMENT"
        "CLUSTER_TYPE"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required variable not set: $var"
            ((errors++))
        fi
    done
    
    # Validate repository type
    if [[ "${REPO_TYPE:-}" != "public" && "${REPO_TYPE:-}" != "private" ]]; then
        error "REPO_TYPE must be 'public' or 'private'"
        ((errors++))
    fi
    
    # Validate cluster type
    if [[ "${CLUSTER_TYPE:-}" != "local" && "${CLUSTER_TYPE:-}" != "aws" ]]; then
        error "CLUSTER_TYPE must be 'local' or 'aws'"
        ((errors++))
    fi
    
    # Validate private repository credentials
    if [[ "${REPO_TYPE:-}" == "private" ]]; then
        local has_token=false
        local has_ssh=false
        
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            has_token=true
        fi
        
        if [[ -n "${GITHUB_SSH_PRIVATE_KEY_PATH:-}" && -f "${GITHUB_SSH_PRIVATE_KEY_PATH}" ]]; then
            has_ssh=true
        fi
        
        if [[ "$has_token" != "true" && "$has_ssh" != "true" ]]; then
            error "Private repository requires either GITHUB_TOKEN or GITHUB_SSH_PRIVATE_KEY_PATH"
            ((errors++))
        fi
        
        if [[ "$has_token" == "true" && "$has_ssh" == "true" ]]; then
            warning "Both GITHUB_TOKEN and GITHUB_SSH_PRIVATE_KEY_PATH are set. Token will be used."
        fi
    fi
    
    # Validate AWS configuration for AWS environments
    if [[ "${CLUSTER_TYPE:-}" == "aws" ]]; then
        local aws_vars=(
            "AWS_REGION"
            "EKS_CLUSTER_VERSION"
            "EKS_NODE_INSTANCE_TYPE"
        )
        
        for var in "${aws_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                error "AWS environment requires: $var"
                ((errors++))
            fi
        done
    fi
    
    # Validate local configuration for local environments
    if [[ "${CLUSTER_TYPE:-}" == "local" ]]; then
        local local_vars=(
            "K3D_CLUSTER_NAME"
            "LOCAL_DOMAIN"
        )
        
        for var in "${local_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                error "Local environment requires: $var"
                ((errors++))
            fi
        done
    fi
    
    # Check repository URL format
    if [[ -n "${REPO_URL:-}" ]]; then
        if [[ ! "${REPO_URL}" =~ ^https://github\.com/ ]]; then
            error "REPO_URL must be a GitHub HTTPS URL"
            ((errors++))
        fi
    fi
    
    # Summary
    if [[ $errors -eq 0 ]]; then
        success "Environment configuration is valid"
        return 0
    else
        error "Found $errors configuration errors"
        return 1
    fi
}

# Show current environment configuration (without secrets)
show_env() {
    if ! check_env_file; then
        error ".env file not found. Run '$0 init' first"
        exit 1
    fi
    
    # Source the environment file
    set -a
    source "$ENV_FILE"
    set +a
    
    echo "Current Environment Configuration:"
    echo "=================================="
    echo
    
    # Repository configuration
    echo "Repository:"
    echo "  URL: ${REPO_URL:-<not set>}"
    echo "  Type: ${REPO_TYPE:-<not set>}"
    echo
    
    # Environment configuration
    echo "Environment:"
    echo "  Name: ${ENVIRONMENT:-<not set>}"
    echo "  Cluster Type: ${CLUSTER_TYPE:-<not set>}"
    echo
    
    # GitHub credentials (masked)
    if [[ "${REPO_TYPE:-}" == "private" ]]; then
        echo "GitHub Credentials:"
        if [[ -n "${GITHUB_USERNAME:-}" ]]; then
            echo "  Username: ${GITHUB_USERNAME}"
        fi
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            echo "  Token: ${GITHUB_TOKEN:0:8}...${GITHUB_TOKEN: -4}"
        fi
        if [[ -n "${GITHUB_SSH_PRIVATE_KEY_PATH:-}" ]]; then
            echo "  SSH Key: ${GITHUB_SSH_PRIVATE_KEY_PATH}"
        fi
        echo
    fi
    
    # AWS configuration
    if [[ "${CLUSTER_TYPE:-}" == "aws" ]]; then
        echo "AWS Configuration:"
        echo "  Region: ${AWS_REGION:-<not set>}"
        echo "  EKS Version: ${EKS_CLUSTER_VERSION:-<not set>}"
        echo "  Node Type: ${EKS_NODE_INSTANCE_TYPE:-<not set>}"
        echo
    fi
    
    # Local configuration
    if [[ "${CLUSTER_TYPE:-}" == "local" ]]; then
        echo "Local Configuration:"
        echo "  Cluster Name: ${K3D_CLUSTER_NAME:-<not set>}"
        echo "  Domain: ${LOCAL_DOMAIN:-<not set>}"
        echo
    fi
    
    # External services
    echo "External Services:"
    echo "  PostgreSQL: ${POSTGRES_ENABLED:-<not set>}"
    echo "  MinIO: ${MINIO_ENABLED:-<not set>}"
    echo "  Redis: ${REDIS_ENABLED:-<not set>}"
    echo
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            shift
            init_env "$@"
            ;;
        validate)
            validate_env
            ;;
        show)
            show_env
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            error "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
