#!/bin/bash
set -e

echo "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create ArgoCD values file
cat > /tmp/argocd-values.yaml << EOF
global:
  domain: argocd.${ENVIRONMENT}.127.0.0.1.nip.io
configs:
  params:
    server.insecure: true
    server.disable.auth: false
  repositories: |
    - url: https://github.com/comind-pro/comind-ops
      name: comind-ops-platform
      type: git
  resource.customizations: |
    argoproj.io/Application:
      health.lua: |
        hs = {}
        hs.status = "Healthy"
        return hs
rbac:
  policy.default: role:readonly
  policy.csv: |
    # Admin policy
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, certificates, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, gpgkeys, *, *, allow
    p, role:admin, logs, *, *, allow
    # Read-only policy
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, applications, list, */*, allow
    p, role:readonly, clusters, get, *, allow
    p, role:readonly, clusters, list, *, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, repositories, list, *, allow
    p, role:readonly, projects, get, *, allow
    p, role:readonly, projects, list, *, allow
    # Bind admin role to admin user
    g, admin, role:admin
    # Bind readonly role to all users by default
    g, argocd, role:readonly
server:
  service:
    type: LoadBalancer
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.${ENVIRONMENT}.127.0.0.1.nip.io
    tls:
      - secretName: argocd-server-tls
        hosts:
          - argocd.${ENVIRONMENT}.127.0.0.1.nip.io
EOF

helm upgrade --install argocd argo/argo-cd \
  --version 5.51.6 \
  --namespace argocd \
  --values /tmp/argocd-values.yaml \
  --wait

echo "✅ ArgoCD installed"
