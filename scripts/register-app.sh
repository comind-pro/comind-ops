#!/bin/bash

# App Registration Script for Comind-Ops Platform
# This script registers new applications (both platform and user apps) in the GitOps structure

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
APP_NAME=""
APP_TYPE="user"  # "platform" or "user"
TEAM=""
REPOSITORY_URL=""
REPOSITORY_PATH=""
DESCRIPTION=""
PORT=8080
ENVIRONMENTS="dev,stage,prod"
AUTO_SYNC_DEV=true
AUTO_SYNC_STAGE=true
AUTO_SYNC_PROD=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Register a new application in the Comind-Ops Platform"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME              Application name (required)"
    echo "  -t, --type TYPE              Application type: platform|user (default: user)"
    echo "  -e, --team TEAM              Team name (required)"
    echo "  -r, --repo URL               Repository URL (required)"
    echo "  -p, --path PATH              Repository path to chart (default: charts/apps/APP_NAME)"
    echo "  -d, --description DESC       Application description"
    echo "  --port PORT                  Application port (default: 8080)"
    echo "  --envs ENVS                  Comma-separated environments (default: dev,stage,prod)"
    echo "  --no-auto-sync-dev           Disable auto-sync for dev environment"
    echo "  --no-auto-sync-stage         Disable auto-sync for stage environment"
    echo "  --auto-sync-prod             Enable auto-sync for prod environment"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Register a user application"
    echo "  $0 -n my-app -e my-team -r https://github.com/my-org/my-app"
    echo ""
    echo "  # Register a platform application"
    echo "  $0 -n platform-service -t platform -e platform -r https://github.com/comind-pro/comind-ops -p charts/infra/platform-service"
    echo ""
    echo "  # Register with custom environments"
    echo "  $0 -n my-app -e my-team -r https://github.com/my-org/my-app --envs dev,prod"
}

# Function to validate inputs
validate_inputs() {
    if [ -z "$APP_NAME" ]; then
        echo -e "${RED}❌ Error: Application name is required${NC}"
        show_usage
        exit 1
    fi

    if [ -z "$TEAM" ]; then
        echo -e "${RED}❌ Error: Team name is required${NC}"
        show_usage
        exit 1
    fi

    if [ -z "$REPOSITORY_URL" ]; then
        echo -e "${RED}❌ Error: Repository URL is required${NC}"
        show_usage
        exit 1
    fi

    if [ "$APP_TYPE" != "platform" ] && [ "$APP_TYPE" != "user" ]; then
        echo -e "${RED}❌ Error: Application type must be 'platform' or 'user'${NC}"
        show_usage
        exit 1
    fi

    # Set default repository path if not provided
    if [ -z "$REPOSITORY_PATH" ]; then
    if [ "$APP_TYPE" = "platform" ]; then
        REPOSITORY_PATH="k8s/charts/platform/$APP_NAME"
    else
        REPOSITORY_PATH="k8s/charts/apps/$APP_NAME"
    fi
    fi
}

# Function to create Helm chart
create_helm_chart() {
    local chart_path="k8s/charts/$APP_TYPE/$APP_NAME"
    
    echo -e "${YELLOW}📦 Creating Helm chart for $APP_NAME...${NC}"
    
    # Create chart directory
    mkdir -p "$chart_path"
    
    # Create Chart.yaml
    cat > "$chart_path/Chart.yaml" << EOF
apiVersion: v2
name: $APP_NAME
description: $DESCRIPTION
type: application
version: 0.1.0
appVersion: "1.0.0"
kubeVersion: ">= 1.23.0-0"

# Metadata
maintainers:
  - name: $TEAM Team
    email: $TEAM@comind-ops.dev

# Classification
keywords:
  - $APP_NAME
  - $APP_TYPE
  - platform
  - comind-ops

home: $REPOSITORY_URL
sources:
  - $REPOSITORY_URL

annotations:
  category: $([ "$APP_TYPE" = "platform" ] && echo "Infrastructure" || echo "Applications")
  platform.comind-ops.io/team: $TEAM
  platform.comind-ops.io/type: $APP_TYPE
  platform.comind-ops.io/ingress: enabled
  platform.comind-ops.io/monitoring: enabled
EOF

    # Create values.yaml
    cat > "$chart_path/values.yaml" << EOF
# Default values for $APP_NAME
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

podSecurityContext:
  fsGroup: 2000

securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

service:
  type: ClusterIP
  port: $PORT

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: $APP_NAME.dev.127.0.0.1.nip.io
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}
EOF

    # Create values directory
    mkdir -p "$chart_path/values"
    
    # Create environment-specific values
    for env in $(echo "$ENVIRONMENTS" | tr ',' ' '); do
        cat > "$chart_path/values/$env.yaml" << EOF
# $env environment values for $APP_NAME
replicaCount: $([ "$env" = "dev" ] && echo "1" || [ "$env" = "stage" ] && echo "2" || echo "3")

image:
  tag: "$env"

ingress:
  enabled: true
  hosts:
    - host: $APP_NAME.$env.127.0.0.1.nip.io
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: $([ "$env" = "dev" ] && echo "500m" || [ "$env" = "stage" ] && echo "1000m" || echo "2000m")
    memory: $([ "$env" = "dev" ] && echo "512Mi" || [ "$env" = "stage" ] && echo "1Gi" || echo "2Gi")
  requests:
    cpu: $([ "$env" = "dev" ] && echo "250m" || [ "$env" = "stage" ] && echo "500m" || echo "1000m")
    memory: $([ "$env" = "dev" ] && echo "256Mi" || [ "$env" = "stage" ] && echo "512Mi" || echo "1Gi")

autoscaling:
  enabled: $([ "$env" = "dev" ] && echo "false" || echo "true")
  minReplicas: $([ "$env" = "dev" ] && echo "1" || [ "$env" = "stage" ] && echo "2" || echo "3")
  maxReplicas: $([ "$env" = "dev" ] && echo "100" || [ "$env" = "stage" ] && echo "8" || echo "20")
  targetCPUUtilizationPercentage: $([ "$env" = "dev" ] && echo "80" || [ "$env" = "stage" ] && echo "70" || echo "60")
EOF
    done

    # Create templates directory
    mkdir -p "$chart_path/templates"
    
    # Create basic templates
    cat > "$chart_path/templates/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "$APP_NAME.fullname" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "$APP_NAME.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "$APP_NAME.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "$APP_NAME.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF

    # Create other basic templates
    helm create "$chart_path" --starter 2>/dev/null || true
    
    echo -e "${GREEN}✅ Helm chart created at $chart_path${NC}"
}

# Function to create ArgoCD applications
create_argocd_apps() {
    echo -e "${YELLOW}🚀 Creating ArgoCD applications...${NC}"
    
    for env in $(echo "$ENVIRONMENTS" | tr ',' ' '); do
        local app_file="k8s/kustomize/$APP_TYPE/$env/$APP_NAME.yaml"
        
        # Determine auto-sync setting
        local auto_sync="false"
        case "$env" in
            "dev")
                auto_sync="$AUTO_SYNC_DEV"
                ;;
            "stage")
                auto_sync="$AUTO_SYNC_STAGE"
                ;;
            "prod")
                auto_sync="$AUTO_SYNC_PROD"
                ;;
        esac
        
        cat > "$app_file" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME-$env
  namespace: argocd
  labels:
    app: $APP_NAME
    environment: $env
    team: $TEAM
    component: $APP_TYPE
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: platform-project
  source:
    repoURL: $REPOSITORY_URL
    targetRevision: main
    path: $REPOSITORY_PATH
    helm:
      valueFiles:
        - values/$env.yaml
      parameters:
        - name: image.tag
          value: "$env"
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAME-$env
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
EOF

        echo -e "${GREEN}✅ ArgoCD application created: $app_file${NC}"
    done
}

# Function to update apps.yaml
update_apps_yaml() {
    echo -e "${YELLOW}📝 Updating apps.yaml configuration...${NC}"
    
    # This would require more complex YAML manipulation
    # For now, we'll create a template that can be manually added
    cat > "apps-$APP_NAME-template.yaml" << EOF
# Add this to apps.yaml under the applications section:

$APP_NAME:
  description: "$DESCRIPTION"
  team: $TEAM
  port: $PORT
  repository:
    url: $REPOSITORY_URL
    path: $REPOSITORY_PATH
  environments:
EOF

    for env in $(echo "$ENVIRONMENTS" | tr ',' ' '); do
        cat >> "apps-$APP_NAME-template.yaml" << EOF
    $env:
      enabled: true
      branch: main
      hostname: $APP_NAME.$env.127.0.0.1.nip.io
      replicas: $([ "$env" = "dev" ] && echo "1" || [ "$env" = "stage" ] && echo "2" || echo "3")
      resources:
        requests:
          cpu: $([ "$env" = "dev" ] && echo "250m" || [ "$env" = "stage" ] && echo "500m" || echo "1000m")
          memory: $([ "$env" = "dev" ] && echo "256Mi" || [ "$env" = "stage" ] && echo "512Mi" || echo "1Gi")
        limits:
          cpu: $([ "$env" = "dev" ] && echo "500m" || [ "$env" = "stage" ] && echo "1000m" || echo "2000m")
          memory: $([ "$env" = "dev" ] && echo "512Mi" || [ "$env" = "stage" ] && echo "1Gi" || echo "2Gi")
      database:
        enabled: false
      monitoring:
        enabled: true
EOF
    done

    echo -e "${GREEN}✅ Template created: apps-$APP_NAME-template.yaml${NC}"
    echo -e "${YELLOW}💡 Please manually add this configuration to apps.yaml${NC}"
}

# Function to show summary
show_summary() {
    echo ""
    echo -e "${GREEN}🎉 Application registration completed!${NC}"
    echo ""
    echo -e "${BLUE}📋 Summary:${NC}"
    echo -e "  Application: $APP_NAME"
    echo -e "  Type: $APP_TYPE"
    echo -e "  Team: $TEAM"
    echo -e "  Repository: $REPOSITORY_URL"
    echo -e "  Path: $REPOSITORY_PATH"
    echo -e "  Environments: $ENVIRONMENTS"
    echo ""
    echo -e "${BLUE}📁 Created files:${NC}"
    echo -e "  Helm chart: k8s/charts/$APP_TYPE/$APP_NAME/"
    for env in $(echo "$ENVIRONMENTS" | tr ',' ' '); do
        echo -e "  ArgoCD app: k8s/kustomize/$APP_TYPE/$env/$APP_NAME.yaml"
    done
    echo -e "  Config template: apps-$APP_NAME-template.yaml"
    echo ""
    echo -e "${BLUE}🚀 Next steps:${NC}"
    echo -e "  1. Review and customize the Helm chart"
    echo -e "  2. Add the configuration to apps.yaml"
    echo -e "  3. Commit and push changes"
    echo -e "  4. ArgoCD will automatically deploy the application"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            APP_NAME="$2"
            shift 2
            ;;
        -t|--type)
            APP_TYPE="$2"
            shift 2
            ;;
        -e|--team)
            TEAM="$2"
            shift 2
            ;;
        -r|--repo)
            REPOSITORY_URL="$2"
            shift 2
            ;;
        -p|--path)
            REPOSITORY_PATH="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --envs)
            ENVIRONMENTS="$2"
            shift 2
            ;;
        --no-auto-sync-dev)
            AUTO_SYNC_DEV=false
            shift
            ;;
        --no-auto-sync-stage)
            AUTO_SYNC_STAGE=false
            shift
            ;;
        --auto-sync-prod)
            AUTO_SYNC_PROD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
echo -e "${BLUE}🚀 Comind-Ops Platform App Registration${NC}"
echo ""

validate_inputs
create_helm_chart
create_argocd_apps
update_apps_yaml
show_summary
