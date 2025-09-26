#!/bin/bash
set -e

echo "Installing Ingress Nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Create ingress-nginx namespace
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Install ingress-nginx with custom values
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version 4.8.3 \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local \
  --wait

echo "✅ Ingress Nginx installed"
