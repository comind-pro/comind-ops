#!/bin/bash
set -euo pipefail

# Comind-Ops Platform - Environment Cleanup Script
# Usage: ./scripts/clean-env.sh [--force]

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

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

echo -e "${BLUE}🧹 COMPREHENSIVE ENVIRONMENT CLEANUP${NC}"
echo ""

if [[ "$FORCE" != "true" ]]; then
    warning "This will completely clean your development environment:"
    echo "  - All Terraform state files and cache directories"
    echo "  - All Docker containers, images, volumes, and networks"  
    echo "  - All k3d clusters and kubectl contexts"
    echo "  - Temporary and backup files"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi
fi

echo ""
log "Starting comprehensive cleanup..."

# Step 1: Terraform cleanup
log "🗂️  Step 1: Cleaning up Terraform state and cache files..."
find infra/terraform -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
find infra/terraform -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
find infra/terraform -name "terraform.tfstate*" -type f -delete 2>/dev/null || true
find infra/terraform -name "terraform.tfstate.d" -type d -exec rm -rf {} + 2>/dev/null || true
success "✅ Terraform cleanup completed"

# Step 2: Docker containers and images
log "🐳 Step 2: Cleaning up Docker containers and images..."
if command -v docker &> /dev/null; then
    # Stop all containers
    if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
        docker stop $(docker ps -q) 2>/dev/null || true
        success "✅ All containers stopped"
    fi
    
    # Remove all containers  
    if [[ $(docker ps -aq | wc -l) -gt 0 ]]; then
        docker rm $(docker ps -aq) 2>/dev/null || true
        success "✅ All containers removed"
    fi
    
    # Remove all images
    if [[ $(docker images -q | wc -l) -gt 0 ]]; then
        docker rmi $(docker images -q) -f 2>/dev/null || true
        success "✅ All images removed"
    fi
else
    warning "Docker not found, skipping Docker cleanup"
fi

# Step 3: Docker volumes and networks
log "🗄️  Step 3: Cleaning up Docker volumes and networks..."
if command -v docker &> /dev/null; then
    # Remove volumes
    if [[ $(docker volume ls -q | wc -l) -gt 0 ]]; then
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        success "✅ All volumes removed"
    fi
    
    # Remove custom networks
    docker network ls --filter type=custom -q | xargs -r docker network rm 2>/dev/null || true
    success "✅ Custom networks removed"
    
    # System prune
    docker system prune -af --volumes 2>/dev/null || true
    success "✅ Docker system cleaned"
fi

# Step 4: k3d clusters
log "☸️  Step 4: Cleaning up k3d clusters..."
if command -v k3d &> /dev/null; then
    k3d cluster delete --all 2>/dev/null || true
    success "✅ All k3d clusters removed"
else
    warning "k3d not found, skipping cluster cleanup"
fi

# Step 5: kubectl contexts
log "🧹 Step 5: Final cleanup tasks..."
if command -v kubectl &> /dev/null; then
    kubectl config get-contexts 2>/dev/null | grep k3d | awk '{print $2}' | xargs -r kubectl config delete-context 2>/dev/null || true
    success "✅ k3d contexts removed"
fi

# Clean temp files
find . -name "*.tmp" -o -name "*.bak" -o -name "*~" 2>/dev/null | head -10 | xargs -r rm -f || true
success "✅ Temp files cleaned"

echo ""
success "🎉 CLEANUP COMPLETE!"
echo ""
log "📊 Verification:"
log "  Terraform dirs:  $(find infra/terraform -name ".terraform*" -type d 2>/dev/null | wc -l | xargs)"
log "  Docker containers: $(docker ps -aq 2>/dev/null | wc -l | xargs)"
log "  Docker images:     $(docker images -q 2>/dev/null | wc -l | xargs)"
log "  k3d clusters:      $(k3d cluster list 2>/dev/null | tail -n +2 | wc -l | xargs)"

echo ""
log "🚀 Ready to bootstrap fresh environment:"
log "  make bootstrap PROFILE=local   # Fresh local k3d environment"
log "  make bootstrap PROFILE=aws     # Fresh AWS EKS environment"
