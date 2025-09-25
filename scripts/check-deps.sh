#!/bin/bash
set -euo pipefail

# Dependency Checker for Comind-Ops Platform
# Verifies all required tools and services are available

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEPS]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

MISSING_DEPS=()
OPTIONAL_DEPS=()

check_command() {
    local cmd="$1"
    local desc="$2"
    local required="${3:-true}"
    
    if command -v "$cmd" &> /dev/null; then
        local version
        case "$cmd" in
            docker)
                version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
                ;;
            kubectl)
                version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
                ;;
            helm)
                version=$(helm version --short | cut -d' ' -f1 | sed 's/v//')
                ;;
            terraform)
                version=$(terraform version | head -1 | cut -d' ' -f2 | sed 's/v//')
                ;;
            yq)
                version=$(yq --version | cut -d' ' -f4)
                ;;
            *)
                version=$(${cmd} --version 2>/dev/null | head -1 || echo "unknown")
                ;;
        esac
        success "$desc ($version)"
    else
        if [[ "$required" == "true" ]]; then
            error "$desc - REQUIRED"
            MISSING_DEPS+=("$cmd")
        else
            warning "$desc - OPTIONAL"
            OPTIONAL_DEPS+=("$cmd")
        fi
    fi
}

check_external_services() {
    log "Checking external services..."
    
    # Check if Docker daemon is running
    if docker ps &> /dev/null; then
        success "Docker daemon is running"
        
        # Check if our external services are running
        if docker ps --format "table {{.Names}}" | grep -q "comind-ops-postgres"; then
            success "PostgreSQL container is running"
        else
            warning "PostgreSQL container not running (use: ./scripts/external-services.sh start)"
        fi
        
        if docker ps --format "table {{.Names}}" | grep -q "comind-ops-minio"; then
            success "MinIO container is running"
        else
            warning "MinIO container not running (use: ./scripts/external-services.sh start)"
        fi
    else
        error "Docker daemon is not running"
        MISSING_DEPS+=("docker-daemon")
    fi
}

check_k8s_cluster() {
    log "Checking Kubernetes cluster..."
    
    if kubectl cluster-info &> /dev/null; then
        local context
        context=$(kubectl config current-context)
        success "Kubernetes cluster accessible (context: $context)"
        
        # Check if it's a k3d cluster
        if [[ "$context" == "k3d-"* ]]; then
            success "k3d cluster detected"
        else
            warning "Non-k3d cluster detected - some features may not work"
        fi
    else
        warning "Kubernetes cluster not accessible (bootstrap will create k3d cluster)"
    fi
}

check_network_connectivity() {
    log "Checking network connectivity..."
    
    # Check if we can resolve DNS
    if nslookup google.com &> /dev/null; then
        success "DNS resolution working"
    else
        error "DNS resolution failed"
        MISSING_DEPS+=("dns")
    fi
    
    # Check if we can reach container registries
    if curl -s --connect-timeout 5 https://registry.hub.docker.com/v2/ &> /dev/null; then
        success "Docker Hub accessible"
    else
        warning "Docker Hub not accessible - may affect image pulls"
    fi
}

check_file_permissions() {
    log "Checking file permissions..."
    
    # Check script permissions
    local scripts=(
        "scripts/new-app.sh"
        "scripts/seal-secret.sh"
        "scripts/tf.sh"
        "scripts/external-services.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            success "$script is executable"
        else
            warning "$script is not executable (fixing...)"
            chmod +x "$script" 2>/dev/null || error "Failed to make $script executable"
        fi
    done
}

print_installation_help() {
    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        echo
        error "Missing required dependencies:"
        
        for dep in "${MISSING_DEPS[@]}"; do
            case "$dep" in
                docker)
                    echo "  Install Docker: https://docs.docker.com/get-docker/"
                    ;;
                kubectl)
                    echo "  Install kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                helm)
                    echo "  Install Helm: https://helm.sh/docs/intro/install/"
                    ;;
                terraform)
                    echo "  Install Terraform: https://learn.hashicorp.com/tutorials/terraform/install-cli"
                    ;;
                k3d)
                    echo "  Install k3d: https://k3d.io/v5.4.6/#installation"
                    ;;
                yamllint)
                    echo "  Install yamllint: pip install yamllint"
                    ;;
                *)
                    echo "  Install $dep"
                    ;;
            esac
        done
        echo
    fi
    
    if [[ ${#OPTIONAL_DEPS[@]} -gt 0 ]]; then
        echo
        warning "Optional dependencies (recommended):"
        for dep in "${OPTIONAL_DEPS[@]}"; do
            case "$dep" in
                yq)
                    echo "  Install yq: https://github.com/mikefarah/yq#install"
                    ;;
                jq)
                    echo "  Install jq: https://stedolan.github.io/jq/download/"
                    ;;
                *)
                    echo "  Install $dep"
                    ;;
            esac
        done
        echo
    fi
}

main() {
    log "Checking Comind-Ops Platform dependencies..."
    echo
    
    # Required tools
    check_command "docker" "Docker" true
    check_command "kubectl" "Kubernetes CLI" true
    check_command "helm" "Helm" true
    check_command "terraform" "Terraform" true
    check_command "k3d" "k3d (local Kubernetes)" true
    check_command "yamllint" "YAML Linter" true
    
    # Optional but recommended tools
    check_command "yq" "YAML Processor" false
    check_command "jq" "JSON Processor" false
    check_command "curl" "HTTP Client" false
    check_command "git" "Version Control" false
    
    echo
    
    # Check services
    check_external_services
    echo
    
    check_k8s_cluster
    echo
    
    check_network_connectivity
    echo
    
    check_file_permissions
    echo
    
    # Summary
    if [[ ${#MISSING_DEPS[@]} -eq 0 ]]; then
        success "All required dependencies are available!"
        
        if [[ ${#OPTIONAL_DEPS[@]} -gt 0 ]]; then
            warning "Some optional dependencies are missing but the platform should work"
        fi
        
        log "Platform is ready for bootstrap!"
        return 0
    else
        error "Missing ${#MISSING_DEPS[@]} required dependencies"
        print_installation_help
        return 1
    fi
}

main "$@"