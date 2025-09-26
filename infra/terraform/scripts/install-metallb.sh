#!/bin/bash
set -e

echo "Installing MetalLB..."
helm repo add metallb https://metallb.github.io/metallb
helm repo update
helm upgrade --install metallb metallb/metallb \
  --version 0.13.12 \
  --namespace metallb-system \
  --wait
echo "✅ MetalLB installed"
