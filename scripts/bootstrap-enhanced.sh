#!/bin/bash
# Enhanced Bootstrap Script for Comind-Ops Platform
# This script provides robust bootstrapping with proper sequencing and error handling

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Configuration from environment
PROFILE="${PROFILE:-local}"
ENV="${ENV:-dev}"
ENVIRONMENTS="${ENV}"

# Function to wait for resource with retry
wait_for_resource() {
    local resource="$1"
    local namespace="${2:-}"
    local timeout="${3:-300}"
    local retries="${4:-5}"

    local namespace_arg=""
    if [ -n "$namespace" ]; then
        namespace_arg="-n $namespace"
    fi

    log "Waiting for $resource to be ready..."

    for i in $(seq 1 $retries); do
        if kubectl wait --for=condition=available --timeout="${timeout}s" $resource $namespace_arg 2>/dev/null; then
            success "$resource is ready"
            return 0
        fi
        warning "Attempt $i/$retries failed, retrying..."
        sleep 10
    done

    error "$resource failed to become ready after $retries attempts"
    return 1
}

# Function to check if ArgoCD is installed
check_argocd() {
    log "Checking ArgoCD installation..."

    # Check if ArgoCD namespace exists
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        warning "ArgoCD namespace not found, will be created"
        return 1
    fi

    # Check if ArgoCD is deployed
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        warning "ArgoCD server not deployed, will be installed"
        return 1
    fi

    # Check if ArgoCD is running
    if kubectl wait --for=condition=available --timeout=30s deployment/argocd-server -n argocd 2>/dev/null; then
        success "ArgoCD is already running"
        return 0
    else
        warning "ArgoCD exists but not ready, will wait"
        return 1
    fi
}

# Function to ensure ArgoCD is properly installed
ensure_argocd() {
    log "Ensuring ArgoCD is properly installed..."

    if check_argocd; then
        return 0
    fi

    # Create namespace if it doesn't exist
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD using Helm
    log "Installing ArgoCD with Helm..."
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update

    # Create values file
    cat > /tmp/argocd-values.yaml << EOF
global:
  domain: argocd.${ENV}.127.0.0.1.nip.io

configs:
  params:
    server.insecure: true
    server.disable.auth: false

server:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.${ENV}.127.0.0.1.nip.io
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
  extraArgs:
    - --insecure

dex:
  enabled: false

redis:
  enabled: true
EOF

    helm upgrade --install argocd argo/argo-cd \
        --version 5.51.6 \
        --namespace argocd \
        --values /tmp/argocd-values.yaml \
        --wait --timeout=10m

    success "ArgoCD installed successfully"

    # Wait for ArgoCD to be fully ready
    wait_for_resource "deployment/argocd-server" "argocd" 300 3
    wait_for_resource "deployment/argocd-repo-server" "argocd" 300 3
    wait_for_resource "deployment/argocd-redis" "argocd" 300 3

    # Get initial admin password
    log "Getting ArgoCD admin password..."
    local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ -n "$admin_password" ]; then
        info "ArgoCD admin password: $admin_password"
        info "ArgoCD UI: http://argocd.${ENV}.127.0.0.1.nip.io:8080"
    fi

    return 0
}

# Function to deploy monitoring dashboard with proper checks
deploy_monitoring() {
    log "Deploying monitoring dashboard..."

    # Create monitoring namespace if it doesn't exist
    kubectl create namespace monitoring-dashboard-dev --dry-run=client -o yaml | kubectl apply -f -

    # Check if monitoring dashboard chart exists
    if [ ! -d "k8s/charts/apps/monitoring-dashboard" ]; then
        warning "Monitoring dashboard chart not found, creating..."
        # Create basic monitoring dashboard structure
        mkdir -p k8s/charts/apps/monitoring-dashboard

        # We'll use the existing monitoring dashboard in k8s/apps if available
        if [ -d "k8s/apps/monitoring-dashboard" ]; then
            cp -r k8s/apps/monitoring-dashboard/* k8s/charts/apps/monitoring-dashboard/ 2>/dev/null || true
        fi
    fi

    # Check if monitoring dashboard deployment exists
    if kubectl get deployment monitoring-dashboard -n monitoring-dashboard-dev >/dev/null 2>&1; then
        success "Monitoring dashboard already deployed"
    else
        # Deploy using kubectl if Helm chart not ready
        log "Deploying monitoring dashboard with kubectl..."

        # Apply the deployment directly if it exists
        if [ -f "k8s/apps/monitoring-dashboard/chart/templates/deployment.yaml" ]; then
            kubectl apply -f k8s/apps/monitoring-dashboard/chart/templates/ -n monitoring-dashboard-dev
        else
            warning "Monitoring dashboard templates not found, skipping"
        fi
    fi

    return 0
}

# Function to verify all services are running
verify_services() {
    log "Verifying all services..."

    local all_good=true

    # Check external services
    if docker ps | grep -q "comind-ops-postgres"; then
        success "PostgreSQL is running"
    else
        error "PostgreSQL is not running"
        all_good=false
    fi

    if docker ps | grep -q "comind-ops-minio"; then
        success "MinIO is running"
    else
        error "MinIO is not running"
        all_good=false
    fi

    # Check Kubernetes cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        success "Kubernetes cluster is accessible"
    else
        error "Kubernetes cluster is not accessible"
        all_good=false
    fi

    # Check ArgoCD
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        if kubectl wait --for=condition=available --timeout=10s deployment/argocd-server -n argocd 2>/dev/null; then
            success "ArgoCD is running"
        else
            warning "ArgoCD is deployed but not ready"
        fi
    else
        error "ArgoCD is not deployed"
        all_good=false
    fi

    # Check ingress controller
    if kubectl get svc ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
        success "Ingress controller is deployed"
    else
        error "Ingress controller is not deployed"
        all_good=false
    fi

    if $all_good; then
        success "All services verified successfully!"
        return 0
    else
        warning "Some services need attention"
        return 1
    fi
}

# Main bootstrap flow
main() {
    log "Starting enhanced bootstrap for Comind-Ops Platform"
    info "Profile: $PROFILE"
    info "Environments: $ENVIRONMENTS"

    # Step 1: Check dependencies
    log "Step 1: Checking dependencies..."
    if ! "$SCRIPT_DIR/check-deps.sh"; then
        error "Dependency check failed"
        exit 1
    fi

    # Step 2: Start external services (local only)
    if [ "$PROFILE" = "local" ]; then
        log "Step 2: Starting external services..."
        "$SCRIPT_DIR/external-services.sh" start --env "$ENV"
    fi

    # Step 3: Wait for cluster to be ready
    log "Step 3: Waiting for Kubernetes cluster..."
    kubectl wait --for=condition=ready node --all --timeout=300s
    success "Kubernetes cluster is ready"

    # Step 4: Ensure ArgoCD is installed
    log "Step 4: Setting up ArgoCD..."
    ensure_argocd

    # Step 5: Apply base resources
    log "Step 5: Applying base Kubernetes resources..."
    kubectl apply -k k8s/base/
    success "Base resources applied"

    # Step 6: Deploy platform services
    log "Step 6: Deploying platform services..."
    kubectl apply -k k8s/platform/
    success "Platform services deployed"

    # Step 7: Deploy Helm charts for environments
    log "Step 7: Deploying environment-specific services..."
    for env in $(echo "$ENVIRONMENTS" | tr ',' ' '); do
        log "Deploying services for $env environment..."

        # Check if namespace exists
        kubectl create namespace "platform-$env" --dry-run=client -o yaml | kubectl apply -f -

        # Deploy Redis
        if [ -f "k8s/charts/platform/redis/values/$env.yaml" ]; then
            helm upgrade --install "redis-$env" k8s/charts/platform/redis \
                -n "platform-$env" \
                -f "k8s/charts/platform/redis/values/$env.yaml" \
                --wait --timeout=5m || warning "Redis deployment for $env failed"
        fi

        # Deploy PostgreSQL
        if [ -f "k8s/charts/platform/postgresql/values/$env.yaml" ]; then
            helm upgrade --install "postgresql-$env" k8s/charts/platform/postgresql \
                -n "platform-$env" \
                -f "k8s/charts/platform/postgresql/values/$env.yaml" \
                --wait --timeout=5m || warning "PostgreSQL deployment for $env failed"
        fi

        # Deploy MinIO
        if [ -f "k8s/charts/platform/minio/values/$env.yaml" ]; then
            helm upgrade --install "minio-$env" k8s/charts/platform/minio \
                -n "platform-$env" \
                -f "k8s/charts/platform/minio/values/$env.yaml" \
                --wait --timeout=5m || warning "MinIO deployment for $env failed"
        fi
    done

    # Step 8: Deploy monitoring
    log "Step 8: Setting up monitoring..."
    deploy_monitoring

    # Step 9: Apply GitOps root application
    log "Step 9: Setting up GitOps..."
    if [ -f "k8s/kustomize/root-app.yaml" ]; then
        kubectl apply -f k8s/kustomize/root-app.yaml
        success "GitOps root application deployed"
    else
        warning "GitOps root application not found"
    fi

    # Step 10: Verify all services
    log "Step 10: Verifying services..."
    verify_services

    # Print access information
    log "Bootstrap completed successfully!"
    echo ""
    info "=== Access Information ==="
    info "ArgoCD UI: http://argocd.$ENV.127.0.0.1.nip.io:8080"
    info "  Username: admin"
    info "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)"
    echo ""
    info "MinIO Console: http://localhost:9001"
    info "  Username: minioadmin"
    info "  Password: minioadmin"
    echo ""
    info "Registry: http://registry.$ENV.127.0.0.1.nip.io:8080"
    echo ""
    info "ElasticMQ: http://elasticmq.$ENV.127.0.0.1.nip.io:8080"
    echo ""
    info "To check service status: make services-status"
    info "To check GitOps status: make gitops-status"

    return 0
}

# Execute main function
main "$@"