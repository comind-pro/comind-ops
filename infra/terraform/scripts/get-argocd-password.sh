#!/bin/bash
set -e

# Get ArgoCD admin password
PASSWORD=""
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
fi

# Output JSON
cat <<EOF
{
  "password": "$PASSWORD"
}
EOF
