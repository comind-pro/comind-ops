#!/bin/bash
set -euo pipefail

# Comind-Ops Platform - Dependency Checker and Auto-Installer
# Ensures all required tools are installed and configured

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS and package manager
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "centos"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Install package based on OS
install_package() {
    local package="$1"
    local os="$2"
    
    case "$os" in
        "macos")
            if ! command -v brew >/dev/null 2>&1; then
                log "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            log "Installing $package via Homebrew..."
            brew install "$package"
            ;;
        "ubuntu")
            log "Installing $package via apt..."
            sudo apt-get update && sudo apt-get install -y "$package"
            ;;
        "centos")
            log "Installing $package via yum..."
            sudo yum install -y "$package"
            ;;
        *)
            error "Unsupported OS. Please install $package manually."
            exit 1
            ;;
    esac
}

# Check and install Docker
check_docker() {
    log "Checking Docker..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker Desktop from https://docker.com/get-started"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker ps >/dev/null 2>&1; then
        log "Docker daemon is not running. Starting Docker..."
        case "$(detect_os)" in
            "macos")
                open -a Docker
                log "Waiting for Docker to start..."
                local timeout=60
                while [ $timeout -gt 0 ]; do
                    if docker ps >/dev/null 2>&1; then
                        break
                    fi
                    sleep 2
                    timeout=$((timeout - 2))
                done
                if [ $timeout -le 0 ]; then
                    error "Docker failed to start within 60 seconds"
                    exit 1
                fi
                ;;
            *)
                sudo systemctl start docker
                sudo systemctl enable docker
                ;;
        esac
    fi
    
    success "✅ Docker is running"
}

# Check and install k3d
check_k3d() {
    log "Checking k3d..."
    
    if ! command -v k3d >/dev/null 2>&1; then
        log "k3d not found. Installing..."
        local os="$(detect_os)"
        case "$os" in
            "macos")
                install_package "k3d" "$os"
                ;;
            "ubuntu"|"linux")
                curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
                ;;
            *)
                error "Please install k3d manually from https://k3d.io"
                exit 1
                ;;
        esac
    fi
    
    success "✅ k3d $(k3d version | head -1 | cut -d' ' -f3)"
}

# Check and install kubectl
check_kubectl() {
    log "Checking kubectl..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log "kubectl not found. Installing..."
        local os="$(detect_os)"
        install_package "kubectl" "$os"
    fi
    
    success "✅ kubectl $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo 'installed')"
}

# Check and install Terraform
check_terraform() {
    log "Checking Terraform..."
    
    if ! command -v terraform >/dev/null 2>&1; then
        log "Terraform not found. Installing..."
        local os="$(detect_os)"
        install_package "terraform" "$os"
    fi
    
    success "✅ Terraform $(terraform version | head -1 | cut -d' ' -f2)"
}

# Check and install Helm
check_helm() {
    log "Checking Helm..."
    
    if ! command -v helm >/dev/null 2>&1; then
        log "Helm not found. Installing..."
        local os="$(detect_os)"
        install_package "helm" "$os"
    fi
    
    success "✅ Helm $(helm version --short)"
}

# Check and install kubeseal
check_kubeseal() {
    log "Checking kubeseal..."
    
    if ! command -v kubeseal >/dev/null 2>&1; then
        log "kubeseal not found. Installing..."
        local os="$(detect_os)"
        install_package "kubeseal" "$os"
    fi
    
    success "✅ kubeseal $(kubeseal --version 2>&1 | head -1 | cut -d' ' -f3)"
}

# Check and install yq
check_yq() {
    log "Checking yq..."
    
    if ! command -v yq >/dev/null 2>&1; then
        log "yq not found. Installing..."
        local os="$(detect_os)"
        install_package "yq" "$os"
    fi
    
    success "✅ yq $(yq --version | cut -d' ' -f4)"
}

# Check and install jq
check_jq() {
    log "Checking jq..."
    
    if ! command -v jq >/dev/null 2>&1; then
        log "jq not found. Installing..."
        local os="$(detect_os)"
        install_package "jq" "$os"
    fi
    
    success "✅ jq $(jq --version)"
}

# Main dependency check
main() {
    log "🔍 Checking and installing dependencies for Comind-Ops Platform..."
    log "OS detected: $(detect_os)"
    echo ""
    
    # Core dependencies
    check_docker
    check_k3d
    check_kubectl
    check_terraform
    check_helm
    check_kubeseal
    check_yq
    check_jq
    
    echo ""
    success "🎉 All dependencies are installed and ready!"
    
    # Verify Docker is accessible
    if ! docker ps >/dev/null 2>&1; then
        error "Docker daemon is not accessible. Please ensure Docker is running."
        exit 1
    fi
    
    # Clean up any stale kubeconfig context
    if kubectl config get-contexts k3d-comind-ops-dev >/dev/null 2>&1; then
        log "Removing stale k3d context..."
        kubectl config delete-context k3d-comind-ops-dev >/dev/null 2>&1 || true
    fi
    
    # Clean up Terraform state if cluster was deleted externally
    if [ -d "infra/terraform/core/.terraform" ]; then
        log "Cleaning up stale Terraform state..."
        rm -rf infra/terraform/core/terraform.tfstate*
        rm -rf infra/terraform/core/.terraform/terraform.tfstate*
    fi
    
    log "🚀 Ready to bootstrap Comind-Ops Platform!"
}

main "$@"
