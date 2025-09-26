#!/bin/bash
set -e

echo "Creating Kubernetes namespaces..."
for namespace in platform-dev platform-stage platform-prod argocd sealed-secrets metallb-system; do
  kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace $namespace app.kubernetes.io/managed-by=terraform --overwrite
done
echo "✅ Namespaces created"
