#!/bin/bash
set -euo pipefail

# Comind-Ops Platform - Secret Sealing Script
# Usage: ./scripts/seal-secret.sh <app-name> <environment> <secret-file>

APP_NAME="${1:-}"
ENVIRONMENT="${2:-}"
SECRET_FILE="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    cat << EOF
Usage: $0 <app-name> <environment> <secret-file>

Arguments:
    app-name        Application name (must match directory in k8s/apps/)
    environment     Target environment (dev, stage, prod)
    secret-file     Path to plain Kubernetes secret YAML file

Options:
    --help          Show this help message
    --dry-run       Show what would be done without executing
    --force         Overwrite existing sealed secret without confirmation
    --namespace NS  Override target namespace (default: <app-name>-<env>)
    --verify        Verify the sealed secret can be decrypted

Examples:
    # Create a plain secret file first
    cat > secret.yaml << EOL
    apiVersion: v1
    kind: Secret
    metadata:
      name: my-app-secrets
      namespace: my-app-dev
    stringData:
      DATABASE_PASSWORD: "super-secret-password"
      API_KEY: "your-api-key-here"
    EOL
    
    # Seal the secret
    $0 my-app dev secret.yaml
    
    # Seal with custom namespace
    $0 my-app prod secret.yaml --namespace my-app-production
    
    # Dry run to see what would happen
    $0 my-app stage secret.yaml --dry-run

Generated Files:
    k8s/apps/<app-name>/secrets/<environment>.sealed.yaml

Requirements:
    - kubeseal CLI tool must be installed
    - sealed-secrets controller must be running in the cluster
    - kubectl must be configured with cluster access
EOF
}

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Default values
DRY_RUN=false
FORCE=false
VERIFY=false
NAMESPACE=""

# Parse command line arguments
while [[ $# -gt 3 ]]; do
    case $4 in
        --help)
            print_usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --namespace)
            NAMESPACE="$5"
            shift 2
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        *)
            error "Unknown option: $4"
            print_usage
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "$APP_NAME" || -z "$ENVIRONMENT" || -z "$SECRET_FILE" ]]; then
    error "All three arguments are required: app-name, environment, secret-file"
    print_usage
    exit 1
fi

if [[ ! "$APP_NAME" =~ ^[a-z0-9-]+$ ]]; then
    error "App name must contain only lowercase letters, numbers, and hyphens"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    error "Environment must be one of: dev, stage, prod"
    exit 1
fi

if [[ ! -f "$SECRET_FILE" ]]; then
    error "Secret file does not exist: $SECRET_FILE"
    exit 1
fi

# Set default namespace if not provided
if [[ -z "$NAMESPACE" ]]; then
    NAMESPACE="$APP_NAME-$ENVIRONMENT"
fi

# Check dependencies
if ! command -v kubeseal &> /dev/null; then
    error "kubeseal CLI tool is not installed"
    echo "Install it with:"
    echo "  # macOS"
    echo "  brew install kubeseal"
    echo "  # Linux"
    echo "  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz"
    echo "  tar -xzf kubeseal-0.24.0-linux-amd64.tar.gz"
    echo "  sudo install -m 755 kubeseal /usr/local/bin/kubeseal"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

# Check if sealed-secrets controller is running
if ! kubectl get pods -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets &> /dev/null; then
    warning "sealed-secrets controller might not be running"
    log "Checking if sealed-secrets controller is available..."
    if ! kubectl get ns sealed-secrets &> /dev/null; then
        error "sealed-secrets namespace does not exist"
        echo "Install sealed-secrets with:"
        echo "  kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml"
        exit 1
    fi
fi

# Validate secret file format
if ! kubectl apply --dry-run=client -f "$SECRET_FILE" &> /dev/null; then
    error "Invalid Kubernetes secret file: $SECRET_FILE"
    log "The file must be a valid Kubernetes Secret manifest"
    exit 1
fi

# Extract secret details
SECRET_NAME=$(yq eval '.metadata.name' "$SECRET_FILE" 2>/dev/null || echo "unknown")
SECRET_NAMESPACE=$(yq eval '.metadata.namespace' "$SECRET_FILE" 2>/dev/null || echo "")

if [[ "$SECRET_NAME" == "unknown" ]]; then
    error "Cannot extract secret name from $SECRET_FILE"
    exit 1
fi

# Update namespace in secret file if needed
TEMP_SECRET_FILE=$(mktemp)
cp "$SECRET_FILE" "$TEMP_SECRET_FILE"

if [[ -n "$NAMESPACE" && "$SECRET_NAMESPACE" != "$NAMESPACE" ]]; then
    log "Updating namespace in secret file to: $NAMESPACE"
    yq eval ".metadata.namespace = \"$NAMESPACE\"" -i "$TEMP_SECRET_FILE" 2>/dev/null || {
        # Fallback for systems without yq
        sed -i.bak "s/namespace: .*/namespace: $NAMESPACE/" "$TEMP_SECRET_FILE"
    }
fi

# Determine output paths
APP_SECRETS_DIR="$PROJECT_ROOT/k8s/apps/$APP_NAME/secrets"
OUTPUT_FILE="$APP_SECRETS_DIR/$ENVIRONMENT.sealed.yaml"

# Create secrets directory if it doesn't exist
if [[ ! -d "$APP_SECRETS_DIR" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would create directory: $APP_SECRETS_DIR"
    else
        mkdir -p "$APP_SECRETS_DIR"
        log "Created directory: $APP_SECRETS_DIR"
    fi
fi

# Check if output file exists and handle overwrite
if [[ -f "$OUTPUT_FILE" && "$FORCE" == "false" && "$DRY_RUN" == "false" ]]; then
    warning "Sealed secret file already exists: $OUTPUT_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborted by user"
        exit 0
    fi
fi

log "Sealing secret..."
log "  App: $APP_NAME"
log "  Environment: $ENVIRONMENT" 
log "  Namespace: $NAMESPACE"
log "  Secret: $SECRET_NAME"
log "  Input: $SECRET_FILE"
log "  Output: $OUTPUT_FILE"

if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would run: kubeseal --controller-name=sealed-secrets-controller --controller-namespace=sealed-secrets --format=yaml --namespace=$NAMESPACE < $TEMP_SECRET_FILE > $OUTPUT_FILE"
    log "[DRY-RUN] Secret sealing simulation complete"
else
    # Create the sealed secret
    if kubeseal --controller-name=sealed-secrets-controller \
                 --controller-namespace=sealed-secrets \
                 --format=yaml --namespace="$NAMESPACE" < "$TEMP_SECRET_FILE" > "$OUTPUT_FILE"; then
        success "✅ Secret sealed successfully!"
        log "Sealed secret saved to: $OUTPUT_FILE"
        
        # Add metadata and annotations for better tracking
        cat > "${OUTPUT_FILE}.tmp" << EOF
# Sealed secret for $APP_NAME in $ENVIRONMENT environment
# Generated: $(date -Iseconds)
# Source: $SECRET_FILE
# Namespace: $NAMESPACE
# 
# To update this secret:
# 1. Edit your plain secret file
# 2. Run: ./scripts/seal-secret.sh $APP_NAME $ENVIRONMENT $SECRET_FILE
# 3. Commit the updated .sealed.yaml file
#
# IMPORTANT: Never commit the plain secret file to git!

EOF
        cat "$OUTPUT_FILE" >> "${OUTPUT_FILE}.tmp"
        mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
        
        # Verify the sealed secret if requested
        if [[ "$VERIFY" == "true" ]]; then
            log "Verifying sealed secret..."
            if kubectl apply --dry-run=server -f "$OUTPUT_FILE" &> /dev/null; then
                success "✅ Sealed secret verification passed"
            else
                warning "⚠️  Sealed secret verification failed (but sealing was successful)"
            fi
        fi
        
        # Git status check
        if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null 2>&1; then
            log "Git status for sealed secret:"
            git status --porcelain "$OUTPUT_FILE" || true
            echo
            log "Next steps:"
            log "  1. Review the sealed secret: cat $OUTPUT_FILE"
            log "  2. Commit to git: git add $OUTPUT_FILE && git commit -m 'Add sealed secret for $APP_NAME $ENVIRONMENT'"
            log "  3. Push to trigger ArgoCD sync: git push"
        fi
        
    else
        error "Failed to seal secret"
        exit 1
    fi
fi

# Cleanup
rm -f "$TEMP_SECRET_FILE"

# Security reminder
warning "Security reminder:"
echo "  - The plain secret file ($SECRET_FILE) contains sensitive data"
echo "  - Do NOT commit plain secret files to git"
echo "  - Only commit the .sealed.yaml files"
echo "  - Consider deleting the plain secret file: rm $SECRET_FILE"
echo
success "Secret sealing complete! 🔒"
