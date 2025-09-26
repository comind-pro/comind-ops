#!/bin/bash
set -e

echo "Installing Sealed Secrets..."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --version 2.13.2 \
  --namespace sealed-secrets \
  --set commandArgs="{--update-status}" \
  --set fullnameOverride=sealed-secrets-controller \
  --wait

echo "✅ Sealed Secrets installed"
