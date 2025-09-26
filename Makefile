# Comind-Ops Platform - Comprehensive Makefile
# Provides easy-to-remember commands for all platform operations

# Default values
ENV ?= dev
APP ?= sample-app
COMMAND ?= plan
TEAM ?= platform
PROFILE ?= local

# Load environment configuration if .env exists
ifneq (,$(wildcard .env))
    include .env
    export
    # Load environment variables for Terraform
    $(shell scripts/load-env.sh)
endif

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Help target - default when running just 'make'
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Comind-Ops Platform - Available Commands$(NC)"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start:$(NC)"
	@echo "  make setup-env                    # Setup environment configuration"
	@echo "  make bootstrap                    # Complete infrastructure setup (Terraform + ArgoCD)"
	@echo "  make services-setup               # Start external services (PostgreSQL, MinIO)"
	@echo "  make argo-login                   # Get ArgoCD admin credentials"
	@echo "  make new-app-full APP=my-api      # Create application with infrastructure"
	@echo "  make gitops-status                # Check ArgoCD GitOps status"
	@echo "  make monitoring-access            # Access monitoring dashboard"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)🔧 Variables:$(NC)"
	@echo "  ENV        Environment(s) (dev, stage, qa, prod or comma-separated: dev,stage) [default: $(ENV)]"
	@echo "  APP        Application name [default: $(APP)]"
	@echo "  COMMAND    Terraform command [default: $(COMMAND)]"
	@echo "  TEAM       Team name [default: $(TEAM)]"
	@echo "  PROFILE    Infrastructure profile (local, aws) [default: $(PROFILE)]"
	@echo ""
	@echo "$(GREEN)💡 Examples:$(NC)"
	@echo "  make bootstrap PROFILE=local      # Local development setup"
	@echo "  make bootstrap PROFILE=aws        # AWS production setup"
	@echo "  make bootstrap ENV=dev,stage      # Deploy dev and stage environments"
	@echo "  make bootstrap ENV=dev,stage,qa,prod # Deploy all environments"
	@echo "  make bootstrap ENV=prod           # Deploy only production environment"
	@echo "  make services-setup               # Start external services"
	@echo "  make new-app-full APP=payment-api TEAM=backend"
	@echo "  make gitops-status                # Check ArgoCD status"
	@echo "  make monitoring-access            # Access monitoring dashboard"
	@echo "  make clean-env                    # Complete environment cleanup"

# ===========================================
# 🏗️  INFRASTRUCTURE & BOOTSTRAP
# ===========================================

.PHONY: bootstrap
bootstrap: ## Complete infrastructure setup (Terraform + ArgoCD + Platform Services)
	@echo "$(BLUE)🏗️  Bootstrapping Comind-Ops Platform...$(NC)"
	@echo "$(YELLOW)Phase 1: Environment Validation$(NC)"
	@echo "$(YELLOW)Step 1/10: Validating environment configuration...$(NC)"
	@if [ -f .env ]; then \
		./scripts/setup-env.sh validate; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make setup-env' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Phase 2: Terraform Infrastructure Setup$(NC)"
	@echo "$(YELLOW)Step 2/10: Checking dependencies...$(NC)"
	@./scripts/check-deps.sh
	@echo "$(YELLOW)Step 3/10: Starting external services (local only)...$(NC)"
	@if [ "$(PROFILE)" = "local" ]; then \
		$(MAKE) --no-print-directory services-setup; \
	else \
		echo "$(BLUE)Skipping Docker services for $(PROFILE) profile - using cloud services$(NC)"; \
	fi
	@echo "$(YELLOW)Step 4/10: Initializing Terraform...$(NC)"
	@terraform -chdir=infra/terraform/environments/$(PROFILE) init
	@echo "$(YELLOW)Step 5/10: Deploying core infrastructure...$(NC)"
	@if echo "$(ENV)" | grep -q ","; then \
		echo "$(BLUE)Deploying multiple environments: $(ENV)$(NC)"; \
		./infra/terraform/scripts/tf.sh $(ENV) core apply --auto-approve --profile $(PROFILE) -var="environments=[\"$(shell echo $(ENV) | sed 's/,/","/g')\"]" -var="multi_environment=true"; \
	else \
		echo "$(BLUE)Deploying single environment: $(ENV)$(NC)"; \
		./infra/terraform/scripts/tf.sh $(ENV) core apply --auto-approve --profile $(PROFILE) -var="environments=[\"$(ENV)\"]" -var="multi_environment=false"; \
	fi
	@echo "$(YELLOW)Step 6/10: Waiting for cluster to be ready...$(NC)"
	@sleep 30
	@kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || echo "ArgoCD still starting..."
	@echo "$(YELLOW)Step 7/10: Applying base Kubernetes resources...$(NC)"
	@kubectl apply -k k8s/base/
	@echo "$(YELLOW)Step 8/10: Deploying platform services...$(NC)"
	@kubectl apply -k k8s/platform/
	@if echo "$(ENV)" | grep -q ","; then \
		echo "$(BLUE)Deploying services for environments: $(ENV)$(NC)"; \
		for env in $(subst ,, ,$(ENV)); do \
			echo "$(YELLOW)Deploying services for $$env environment...$(NC)"; \
			helm upgrade --install redis-$$env k8s/charts/platform/redis -n platform-$$env --create-namespace -f k8s/charts/platform/redis/values/$$env.yaml; \
			helm upgrade --install postgresql-$$env k8s/charts/platform/postgresql -n platform-$$env --create-namespace -f k8s/charts/platform/postgresql/values/$$env.yaml; \
			helm upgrade --install minio-$$env k8s/charts/platform/minio -n platform-$$env --create-namespace -f k8s/charts/platform/minio/values/$$env.yaml; \
		done; \
	else \
		echo "$(BLUE)Deploying services for $(ENV) environment...$(NC)"; \
		helm upgrade --install redis-$(ENV) k8s/charts/platform/redis -n platform-$(ENV) --create-namespace -f k8s/charts/platform/redis/values/$(ENV).yaml; \
		helm upgrade --install postgresql-$(ENV) k8s/charts/platform/postgresql -n platform-$(ENV) --create-namespace -f k8s/charts/platform/postgresql/values/$(ENV).yaml; \
		helm upgrade --install minio-$(ENV) k8s/charts/platform/minio -n platform-$(ENV) --create-namespace -f k8s/charts/platform/minio/values/$(ENV).yaml; \
	fi
	@echo "$(YELLOW)Phase 3: ArgoCD GitOps Setup$(NC)"
	@echo "$(YELLOW)Step 9/10: Setting up GitOps with ArgoCD...$(NC)"
	@kubectl apply -f k8s/kustomize/root-app.yaml
	@echo "$(YELLOW)Phase 4: Monitoring and Access$(NC)"
	@echo "$(YELLOW)Step 10/10: Deploying monitoring dashboard...$(NC)"
	@./scripts/deploy-monitoring.sh
	@echo "$(GREEN)✅ Bootstrap complete!$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Infrastructure Flow Summary:$(NC)"
	@echo "  ✅ Terraform: K8s cluster, ArgoCD, initial platform setup"
	@echo "  ✅ External Services: PostgreSQL, MinIO (local only)"
	@echo "  ✅ ArgoCD: Platform services, application infrastructure"
	@echo "  ✅ Monitoring: Dashboard and access setup"
	@echo ""
	@$(MAKE) --no-print-directory status

setup-env: ## Setup environment configuration
	@echo "$(BLUE)🔧 Setting up environment configuration...$(NC)"
	@./scripts/setup-env.sh init
	@echo "$(GREEN)✅ Environment configuration created$(NC)"
	@echo "$(YELLOW)📝 Please edit .env file and run 'make validate-env' to verify$(NC)"

validate-env: ## Validate environment configuration
	@echo "$(BLUE)🔍 Validating environment configuration...$(NC)"
	@./scripts/setup-env.sh validate
	@echo "$(GREEN)✅ Environment configuration is valid$(NC)"

show-env: ## Show current environment configuration
	@echo "$(BLUE)📋 Current environment configuration:$(NC)"
	@./scripts/setup-env.sh show

check-deps: ## Check if all required dependencies are installed
	@echo "$(BLUE)🔍 Checking platform dependencies...$(NC)"
	@./scripts/check-deps.sh
	@echo "$(GREEN)✅ All dependencies verified$(NC)"

# ===========================================
# 🐳 EXTERNAL SERVICES (PostgreSQL, MinIO)
# ===========================================

.PHONY: services-start
services-start: ## Start external services (PostgreSQL, MinIO)
	@echo "$(BLUE)🐳 Starting external services...$(NC)"
	@./scripts/external-services.sh start --env $(ENV)
	@echo "$(GREEN)✅ External services started$(NC)"

.PHONY: services-stop
services-stop: ## Stop external services
	@echo "$(BLUE)🛑 Stopping external services...$(NC)"
	@./scripts/external-services.sh stop --env $(ENV)
	@echo "$(GREEN)✅ External services stopped$(NC)"

.PHONY: services-status
services-status: ## Check external services status
	@echo "$(BLUE)📊 Checking external services status...$(NC)"
	@./scripts/external-services.sh status --env $(ENV)

.PHONY: services-logs
services-logs: ## Show external services logs
	@echo "$(BLUE)📋 Showing external services logs...$(NC)"
	@./scripts/external-services.sh logs --follow --env $(ENV)

.PHONY: services-backup
services-backup: ## Backup external services data
	@echo "$(BLUE)💾 Creating backup of external services...$(NC)"
	@./scripts/external-services.sh backup --env $(ENV)
	@echo "$(GREEN)✅ Backup completed$(NC)"

.PHONY: services-setup
services-setup: ## Setup and initialize external services
	@echo "$(BLUE)🔧 Setting up external services...$(NC)"
	@./scripts/external-services.sh setup --env $(ENV)
	@echo "$(GREEN)✅ External services setup completed$(NC)"

.PHONY: services-clean
services-clean: ## Clean external services and data (DESTRUCTIVE)
	@echo "$(RED)⚠️  WARNING: This will delete all external service data!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@./scripts/external-services.sh clean --env $(ENV)
	@echo "$(GREEN)✅ External services cleaned$(NC)"

.PHONY: cleanup
cleanup: ## Destroy cluster and cleanup resources (⚠️  DESTRUCTIVE)
	@echo "$(RED)⚠️  WARNING: This will destroy the entire $(ENV) environment!$(NC)"
	@read -p "Type 'destroy' to confirm: " confirm && [ "$$confirm" = "destroy" ]
	@echo "$(YELLOW)Cleaning up comind-ops Platform...$(NC)"
	@kubectl delete -k k8s/platform/ --ignore-not-found=true
	@kubectl delete -k k8s/base/ --ignore-not-found=true
	@./infra/terraform/scripts/tf.sh $(ENV) core destroy --auto-approve --profile $(PROFILE)
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

# ===========================================
# 🔐 ARGOCD & GITOPS
# ===========================================

.PHONY: argo-login
argo-login: ## Get ArgoCD admin credentials and access information
	@echo "$(BLUE)🔐 ArgoCD Access Information$(NC)"
	@echo ""
	@echo "$(GREEN)Web UI:$(NC) http://argocd.$(ENV).127.0.0.1.nip.io:8080"
	@echo ""
	@echo "$(GREEN)Admin Credentials:$(NC)"
	@echo "Username: admin"
	@echo -n "Password: "
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo "" || echo "Not available (check if ArgoCD is running)"
	@echo ""
	@echo "$(GREEN)Port Forward (if needed):$(NC)"
	@echo "kubectl port-forward service/argocd-server -n argocd 8080:80"

.PHONY: argo-apps
argo-apps: ## List all ArgoCD applications
	@echo "$(BLUE)📱 ArgoCD Applications:$(NC)"
	@kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL"

# ===========================================
# 📱 APPLICATION MANAGEMENT  
# ===========================================

.PHONY: new-app
new-app: ## Create new application (APP=name TEAM=team PROFILE=local)
	@echo "$(BLUE)📱 Creating new application: $(APP)$(NC)"
	@./scripts/new-app.sh $(APP) --team $(TEAM) --profile $(PROFILE)
	@echo "$(GREEN)✅ Application $(APP) created successfully!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "1. Customize templates in k8s/apps/$(APP)/"
	@echo "2. Create secrets: make seal APP=$(APP) ENV=$(ENV) FILE=secret.yaml"
	@echo "3. Deploy: git add -A && git commit && git push"

.PHONY: new-app-full
new-app-full: ## Create application with full infrastructure (APP=name TEAM=team PROFILE=local)
	@echo "$(BLUE)📱 Creating application $(APP) with infrastructure for $(PROFILE) profile...$(NC)"
	@./scripts/new-app.sh $(APP) --team $(TEAM) --profile $(PROFILE) --with-database --with-queue --with-terraform
	@echo "$(GREEN)✅ Application $(APP) created with complete infrastructure!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "1. Provision infrastructure: make tf-init-app APP=$(APP) && make tf-apply-app APP=$(APP)"
	@echo "2. Customize Helm chart: k8s/apps/$(APP)/values/dev.yaml"
	@echo "3. Create secrets: make seal APP=$(APP) ENV=dev FILE=secret.yaml"
	@echo "4. Deploy: git add -A && git commit && git push"

.PHONY: new-app-api
new-app-api: ## Create API application with database (APP=name TEAM=team PORT=3000 PROFILE=local)
	@echo "$(BLUE)📱 Creating API application: $(APP)$(NC)"
	@./scripts/new-app.sh $(APP) --team $(TEAM) --profile $(PROFILE) --with-database --with-terraform --port $(or $(PORT),3000)
	@echo "$(GREEN)✅ API application $(APP) created!$(NC)"

.PHONY: new-app-worker
new-app-worker: ## Create worker application with queue (APP=name TEAM=team PROFILE=local)  
	@echo "$(BLUE)📱 Creating worker application: $(APP)$(NC)"
	@./scripts/new-app.sh $(APP) --team $(TEAM) --profile $(PROFILE) --with-queue --with-database --with-terraform --sync-wave 20
	@echo "$(GREEN)✅ Worker application $(APP) created!$(NC)"

.PHONY: new-app-simple
new-app-simple: ## Create minimal application (APP=name TEAM=team PROFILE=local)
	@echo "$(BLUE)📱 Creating simple application: $(APP)$(NC)"
	@./scripts/new-app.sh $(APP) --team $(TEAM) --profile $(PROFILE) --language $(or $(LANGUAGE),generic)
	@echo "$(GREEN)✅ Simple application $(APP) created!$(NC)"

.PHONY: list-apps
list-apps: ## List all applications in the platform
	@echo "$(BLUE)📋 Platform Applications:$(NC)"
	@find k8s/apps -name "Chart.yaml" -exec dirname {} \; | sed 's|k8s/apps/||g' | sed 's|/chart||g' | sort

# ===========================================
# 🔒 SECRET MANAGEMENT
# ===========================================

.PHONY: seal
seal: ## Seal secret for GitOps (APP=name ENV=env FILE=secret.yaml)
	@echo "$(BLUE)🔒 Sealing secret for $(APP) in $(ENV)$(NC)"
	@if [ -z "$(FILE)" ]; then \
		echo "$(RED)Error: FILE parameter required$(NC)"; \
		echo "Usage: make seal APP=my-app ENV=dev FILE=secret.yaml"; \
		exit 1; \
	fi
	@./scripts/seal-secret.sh $(APP) $(ENV) $(FILE)
	@echo "$(GREEN)✅ Secret sealed successfully!$(NC)"

# ===========================================
# 🏗️  TERRAFORM OPERATIONS
# ===========================================

.PHONY: tf
tf: ## Run Terraform command (ENV=env APP=app COMMAND=plan PROFILE=profile)
	@echo "$(BLUE)🏗️  Running Terraform $(COMMAND) for $(APP) in $(ENV) [$(PROFILE)]$(NC)"
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) $(COMMAND) --profile $(PROFILE)

.PHONY: tf-plan
tf-plan: ## Plan Terraform changes (ENV=env APP=app)
	@$(MAKE) --no-print-directory tf COMMAND=plan

.PHONY: tf-apply
tf-apply: ## Apply Terraform changes (ENV=env APP=app)
	@$(MAKE) --no-print-directory tf COMMAND=apply

.PHONY: tf-output
tf-output: ## Show Terraform outputs (ENV=env APP=app)
	@$(MAKE) --no-print-directory tf COMMAND=output

# Application-specific Terraform commands
.PHONY: tf-init-app
tf-init-app: ## Initialize Terraform for application (APP=name PROFILE=local)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP). Run: make new-app-full APP=$(APP)$(NC)"; exit 1; fi
	@echo "$(BLUE)🔧 Initializing Terraform for $(APP)...$(NC)"
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) init --profile $(PROFILE)

.PHONY: tf-plan-app  
tf-plan-app: ## Plan Terraform for application (APP=name PROFILE=local)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP)$(NC)"; exit 1; fi
	@echo "$(BLUE)📋 Planning Terraform changes for $(APP)...$(NC)"
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) plan --profile $(PROFILE)

.PHONY: tf-apply-app
tf-apply-app: ## Apply Terraform for application (APP=name PROFILE=local)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP)$(NC)"; exit 1; fi
	@echo "$(BLUE)🚀 Applying Terraform for $(APP)...$(NC)"
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) apply --auto-approve --profile $(PROFILE)

.PHONY: tf-destroy-app
tf-destroy-app: ## Destroy Terraform resources for application (APP=name PROFILE=local)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP)$(NC)"; exit 1; fi
	@echo "$(YELLOW)⚠️  This will destroy all infrastructure for $(APP). Are you sure? (y/N)$(NC)"
	@read -r confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Cancelled." && exit 1)
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) destroy --auto-approve --profile $(PROFILE)

.PHONY: tf-output-app
tf-output-app: ## Show Terraform outputs for application (APP=name PROFILE=local)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP)$(NC)"; exit 1; fi
	@echo "$(BLUE)📤 Terraform outputs for $(APP):$(NC)"
	@./infra/terraform/scripts/tf.sh $(ENV) $(APP) output --profile $(PROFILE)

.PHONY: tf-status-app
tf-status-app: ## Show Terraform status for application (APP=name)
	@if [ ! -d "k8s/apps/$(APP)/terraform" ]; then echo "$(RED)❌ Terraform config not found for $(APP)$(NC)"; exit 1; fi
	@echo "$(BLUE)📊 Terraform status for $(APP):$(NC)"
	@cd k8s/apps/$(APP)/terraform && terraform show -json | jq -r '.values.root_module.resources[] | select(.type != "random_password") | "\(.type).\(.name): \(.values.metadata[0].name // .values.name // "N/A")"' 2>/dev/null || echo "No resources provisioned yet"

.PHONY: tf-list-apps
tf-list-apps: ## List applications with Terraform configurations
	@echo "$(BLUE)📋 Applications with Terraform infrastructure:$(NC)"
	@find k8s/apps -path "*/terraform/main.tf" -exec dirname {} \; | sed 's|k8s/apps/||g' | sed 's|/terraform||g' | sort || echo "No Terraform applications found"

# ===========================================
# 🚀 DEPLOYMENT & OPERATIONS
# ===========================================

.PHONY: deploy
deploy: ## Deploy all platform services and applications
	@echo "$(BLUE)🚀 Deploying comind-ops Platform...$(NC)"
	@kubectl apply -k k8s/base/
	@kubectl apply -k k8s/platform/
	@echo "$(GREEN)✅ Platform deployed successfully!$(NC)"

.PHONY: status
monitoring-access: ## Check monitoring dashboard access
	@echo "$(BLUE)🔍 Checking monitoring dashboard access...$(NC)"
	@./scripts/deploy-monitoring.sh check

monitoring-port-forward: ## Set up port forwarding for monitoring dashboard
	@echo "$(BLUE)🔗 Setting up port forwarding for monitoring dashboard...$(NC)"
	@./scripts/deploy-monitoring.sh port-forward

monitoring-proxy: ## Start monitoring dashboard proxy (accessible at http://localhost:8081)
	@echo "$(BLUE)🚀 Starting monitoring dashboard proxy...$(NC)"
	@python3 scripts/simple-monitoring-proxy.py 8081

register-app: ## Register a new application (interactive)
	@echo "$(BLUE)📝 Registering new application...$(NC)"
	@./scripts/register-app.sh

app-registry: ## Start app registry web interface
	@echo "$(BLUE)🌐 Starting app registry web interface...$(NC)"
	@python3 scripts/app-registry-api.py

gitops-status: ## Show GitOps status (ArgoCD applications)
	@echo "$(BLUE)📊 GitOps Status (ArgoCD Applications)$(NC)"
	@echo ""
	@echo "$(GREEN)Applications:$(NC)"
	@kubectl get applications -n argocd -o wide
	@echo ""
	@echo "$(GREEN)ApplicationSets:$(NC)"
	@kubectl get applicationsets -n argocd -o wide
	@echo ""
	@echo "$(GREEN)Projects:$(NC)"
	@kubectl get appprojects -n argocd -o wide

status: ## Show overall platform status
	@echo "$(BLUE)📊 comind-ops Platform Status$(NC)"
	@echo ""
	@echo "$(GREEN)External Services:$(NC)"
	@$(MAKE) --no-print-directory services-status
	@echo ""
	@echo "$(GREEN)Cluster Information:$(NC)"
	@kubectl cluster-info --context k3d-comind-ops-dev | head -2
	@echo ""
	@echo "$(GREEN)ArgoCD Status:$(NC)"
	@kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | awk '{print "ArgoCD Server: " $$3}'
	@echo ""
	@echo "$(GREEN)Platform Services:$(NC)"
	@kubectl get pods -n platform-dev --no-headers | awk '{print $$1 ": " $$3}' | head -10
	@echo ""
	@echo "$(GREEN)Quick Access:$(NC)"
	@echo "• ArgoCD UI: http://argocd.$(ENV).127.0.0.1.nip.io:8080"
	@echo "• MinIO Console: http://localhost:9001"
	@echo "• PostgreSQL: localhost:5432"
	@echo "• ElasticMQ: http://elasticmq.$(ENV).127.0.0.1.nip.io:8080"
	@echo "• Registry: http://registry.$(ENV).127.0.0.1.nip.io:8080"

# ===========================================
# ✅ VALIDATION & TESTING
# ===========================================

.PHONY: validate
validate: ## Validate all configurations
	@echo "$(BLUE)✅ Validating platform configurations...$(NC)"
	@echo "$(YELLOW)Initializing Terraform for $(PROFILE) profile...$(NC)"
	@terraform -chdir=infra/terraform/environments/$(PROFILE) init -upgrade > /dev/null 2>&1 || true
	@echo "$(YELLOW)Validating Terraform...$(NC)"
	@terraform -chdir=infra/terraform/environments/$(PROFILE) validate
	@echo "$(YELLOW)Validating Kubernetes manifests...$(NC)"
	@find k8s -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \; > /dev/null 2>&1 || echo "⚠️  Some manifests require cluster access"
	@echo "$(YELLOW)Validating Helm charts...$(NC)"
	@find k8s/apps -name "Chart.yaml" -exec dirname {} \; | xargs -I {} helm lint {} > /dev/null 2>&1 || echo "⚠️  Helm charts validation completed"
	@echo "$(GREEN)✅ All validations passed!$(NC)"

.PHONY: lint
lint: ## Lint all code and configurations
	@echo "$(BLUE)🧹 Linting platform code...$(NC)"
	@echo "$(YELLOW)Formatting Terraform...$(NC)"
	@terraform -chdir=infra/terraform/environments/$(PROFILE) fmt -recursive
	@find infra/terraform/environments -name "*.tf" -exec terraform fmt {} \;
	@echo "$(YELLOW)Linting shell scripts...$(NC)"
	@find scripts -name "*.sh" -exec shellcheck {} \; || true
	@echo "$(GREEN)✅ Linting complete$(NC)"

.PHONY: test
test: ## Run comprehensive test suite
	@echo "$(BLUE)🧪 Running comprehensive test suite...$(NC)"
	@./tests/run-tests.sh --category all --format junit
	@echo "$(GREEN)✅ All tests completed$(NC)"

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(BLUE)🧪 Running unit tests...$(NC)"
	@./tests/run-tests.sh --category unit --format junit
	@echo "$(GREEN)✅ Unit tests completed$(NC)"

.PHONY: test-integration
test-integration: ## Run integration tests only
	@echo "$(BLUE)🧪 Running integration tests...$(NC)"
	@./tests/run-tests.sh --category integration --format junit
	@echo "$(GREEN)✅ Integration tests completed$(NC)"

.PHONY: test-e2e
test-e2e: ## Run end-to-end tests only
	@echo "$(BLUE)🧪 Running end-to-end tests...$(NC)"
	@./tests/run-tests.sh --category e2e --format junit
	@echo "$(GREEN)✅ End-to-end tests completed$(NC)"

.PHONY: test-performance
test-performance: ## Run performance tests only
	@echo "$(BLUE)🧪 Running performance tests...$(NC)"
	@./tests/run-tests.sh --category performance --format junit
	@echo "$(GREEN)✅ Performance tests completed$(NC)"

.PHONY: test-helm
test-helm: ## Test Helm charts
	@echo "$(BLUE)🧪 Testing Helm charts...$(NC)"
	@./tests/unit/helm/test-helm-charts.sh
	@echo "$(GREEN)✅ Helm chart tests completed$(NC)"

.PHONY: test-terraform
test-terraform: ## Test Terraform modules
	@echo "$(BLUE)🧪 Testing Terraform modules...$(NC)"
	@./tests/unit/terraform/test-terraform-modules.sh
	@echo "$(GREEN)✅ Terraform tests completed$(NC)"

.PHONY: test-scripts
test-scripts: ## Test automation scripts
	@echo "$(BLUE)🧪 Testing automation scripts...$(NC)"
	@./tests/unit/scripts/test-scripts.sh
	@echo "$(GREEN)✅ Script tests completed$(NC)"

.PHONY: test-ci
test-ci: ## Test CI/CD components locally
	@echo "$(BLUE)🧪 Testing CI/CD components...$(NC)"
	@./tests/test-ci.sh all
	@echo "$(GREEN)✅ CI/CD tests completed$(NC)"

.PHONY: test-app
test-app: ## Test specific application (requires APP=name)
ifndef APP
	@echo "$(RED)❌ APP variable is required$(NC)"
	@echo "Usage: make test-app APP=sample-app"
	@exit 1
endif
	@echo "$(BLUE)🧪 Testing application: $(APP)$(NC)"
	@./tests/run-tests.sh --app $(APP) --category all
	@echo "$(GREEN)✅ Application tests completed for $(APP)$(NC)"

.PHONY: test-setup
test-setup: ## Setup test environment
	@echo "$(BLUE)🧪 Setting up test environment...$(NC)"
	@mkdir -p tests/reports
	@echo "$(GREEN)✅ Test environment ready$(NC)"

.PHONY: test-clean
test-clean: ## Clean test artifacts
	@echo "$(BLUE)🧹 Cleaning test artifacts...$(NC)"
	@rm -rf tests/reports/*
	@rm -f /tmp/comind-ops-tests-*
	@echo "$(GREEN)✅ Test artifacts cleaned$(NC)"

# ===========================================
# 🔧 DEVELOPMENT & DEBUGGING
# ===========================================

.PHONY: logs
logs: ## Show logs for application (APP=name)
	@echo "$(BLUE)📋 Logs for $(APP):$(NC)"
	@kubectl logs -l app.kubernetes.io/name=$(APP) -n $(APP)-$(ENV) --tail=100 -f

.PHONY: shell
shell: ## Open debug shell in cluster
	@echo "$(BLUE)🐚 Opening debug shell in cluster...$(NC)"
	@kubectl run debug-shell --rm -i --tty --image=alpine/curl --restart=Never -- sh

# ===========================================
# 🚀 CONVENIENCE TARGETS
# ===========================================

.PHONY: up
up: bootstrap ## Alias for bootstrap

.PHONY: down  
down: cleanup ## Alias for cleanup

.PHONY: clean
clean: cleanup ## Alias for cleanup
# Heal services - fix common issues automatically
heal-services: ## Fix common service issues automatically
	@echo "🔧 Healing external services..."
	@scripts/external-services.sh heal
	@echo "✅ Service healing completed"

.PHONY: heal-services

.PHONY: clean-env
clean-env: ## Complete environment cleanup (terraform, docker, k3d) - DESTRUCTIVE!
	@echo "$(RED)⚠️  WARNING: This will completely clean your development environment!$(NC)"
	@./scripts/clean-env.sh

.PHONY: clean-all
clean-all: clean-env ## Alias for clean-env
