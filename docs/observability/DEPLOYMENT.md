# Observability Stack Deployment Guide

Quick guide to deploy the complete observability stack (Prometheus, Loki, Promtail, Grafana) managed by ArgoCD.

## 🚀 Quick Deployment

### Prerequisites

- Kubernetes cluster (k3d/EKS/GKE)
- ArgoCD installed and configured
- `kubectl` configured to access cluster
- Sufficient storage (30Gi for dev, 120Gi for prod)

### Step 1: Deploy Observability Applications

```bash
# For Development Environment
kubectl apply -f k8s/kustomize/observability/dev/kustomization.yaml

# For Staging Environment
kubectl apply -f k8s/kustomize/observability/stage/kustomization.yaml

# For Production Environment
kubectl apply -f k8s/kustomize/observability/prod/kustomization.yaml
```

### Step 2: Verify ArgoCD Applications

```bash
# Check application status
kubectl get applications -n argocd | grep -E "prometheus|loki|grafana|promtail"

# Expected output:
# prometheus    Synced    Healthy
# loki          Synced    Healthy
# promtail      Synced    Healthy
# grafana       Synced    Healthy

# Watch sync progress
watch kubectl get applications -n argocd -l app.kubernetes.io/component=monitoring
```

### Step 3: Verify Pod Deployment

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Expected pods:
# prometheus-kube-prometheus-prometheus-0
# prometheus-operator-*
# alertmanager-kube-prometheus-alertmanager-0
# loki-0
# promtail-* (one per node)
# grafana-*

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kube-prometheus-stack -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

### Step 4: Access Grafana

```bash
# Get Grafana URL (if Ingress is configured)
kubectl get ingress -n monitoring grafana
# URL: http://grafana.dev.127.0.0.1.nip.io

# Or use port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access Grafana at http://localhost:3000
# Default credentials:
#   Username: admin
#   Password: changeme123
```

### Step 5: Verify Datasources

```bash
# Check datasources in Grafana
# Navigate to: Configuration > Data Sources

# Should see:
# 1. Prometheus (default) - http://prometheus-kube-prometheus-prometheus.monitoring:9090
# 2. Loki - http://loki-gateway.monitoring:80

# Test queries:
# Prometheus: up
# Loki: {namespace="monitoring"}
```

---

## 🔧 ArgoCD Sync Waves

The deployment follows this order:

1. **Wave 0**: Prometheus, Loki (deployed simultaneously)
2. **Wave 1**: Promtail (after Loki is ready)
3. **Wave 2**: Grafana (after Prometheus and Loki are ready)

---

## 📦 What Gets Deployed

### Namespace: `monitoring`

| Component | Type | Replicas | Storage |
|-----------|------|----------|---------|
| Prometheus | StatefulSet | 1 | 50Gi (prod) / 10Gi (dev) |
| Alertmanager | StatefulSet | 1 | 10Gi (prod) / 5Gi (dev) |
| Prometheus Operator | Deployment | 1 | - |
| Node Exporter | DaemonSet | N (all nodes) | - |
| Kube State Metrics | Deployment | 1 | - |
| Loki | StatefulSet | 1 | 50Gi (prod) / 10Gi (dev) |
| Loki Gateway | Deployment | 1 | - |
| Promtail | DaemonSet | N (all nodes) | - |
| Grafana | Deployment | 1 | 10Gi (prod) / 5Gi (dev) |

---

## 🎯 Accessing Services

### Grafana Dashboard

```bash
# Via Ingress (configured)
http://grafana.dev.127.0.0.1.nip.io

# Via Port Forward
kubectl port-forward -n monitoring svc/grafana 3000:80
http://localhost:3000
```

### Prometheus UI

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
http://localhost:9090
```

### Alertmanager UI

```bash
# Port forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
http://localhost:9093
```

---

## 🔍 Verification Checklist

- [ ] All ArgoCD applications show "Synced" and "Healthy"
- [ ] All pods in monitoring namespace are "Running"
- [ ] Grafana is accessible via Ingress or port-forward
- [ ] Can login to Grafana with admin credentials
- [ ] Prometheus datasource is connected (green checkmark)
- [ ] Loki datasource is connected (green checkmark)
- [ ] Can view pre-installed dashboards
- [ ] Prometheus is scraping metrics (check /targets)
- [ ] Loki is receiving logs (check Explore)
- [ ] Promtail pods are running on all nodes

---

## 🐛 Troubleshooting Deployment

### ArgoCD Application Not Syncing

```bash
# Check application details
kubectl describe application prometheus -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
kubectl patch application prometheus -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n monitoring

# Check logs
kubectl logs <pod-name> -n monitoring

# Common issues:
# 1. Insufficient storage - increase PVC size
# 2. Resource constraints - increase node capacity
# 3. Image pull errors - check image registry access
```

### PVC Pending

```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get storageclass

# If no default storage class:
kubectl patch storageclass <storage-class-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Datasources Not Connecting

```bash
# Test Prometheus connectivity from Grafana pod
kubectl exec -n monitoring deployment/grafana -- \
  wget -qO- http://prometheus-kube-prometheus-prometheus.monitoring:9090/-/healthy

# Test Loki connectivity from Grafana pod
kubectl exec -n monitoring deployment/grafana -- \
  wget -qO- http://loki-gateway.monitoring/ready

# If failing, check service endpoints
kubectl get endpoints -n monitoring prometheus-kube-prometheus-prometheus
kubectl get endpoints -n monitoring loki-gateway
```

---

## 🔄 Update Deployment

### Update Configuration

```bash
# 1. Edit values files
vim k8s/charts/platform/prometheus/values.yaml
vim k8s/charts/platform/loki/values.yaml
vim k8s/charts/platform/grafana/values.yaml

# 2. Commit changes
git add k8s/charts/platform/
git commit -m "Update observability stack configuration"
git push

# 3. ArgoCD will auto-sync (or manual sync)
kubectl patch application prometheus -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Update Helm Chart Versions

```bash
# 1. Update Chart.yaml dependencies
cd k8s/charts/platform/prometheus
vim Chart.yaml  # Update version

# 2. Update dependencies
helm dependency update

# 3. Commit and push
git add .
git commit -m "Update Prometheus chart version"
git push
```

---

## 🔒 Production Checklist

Before deploying to production:

- [ ] **Change Grafana admin password**
  ```bash
  # Use sealed secrets or external secret manager
  kubectl create secret generic grafana-admin \
    --from-literal=admin-password=<secure-password> \
    --namespace monitoring \
    --dry-run=client -o yaml | \
    kubeseal -o yaml > grafana-admin-sealed.yaml
  ```

- [ ] **Configure persistent storage class**
  ```yaml
  # In values.yaml
  storageClassName: fast-ssd  # Or your preferred storage class
  ```

- [ ] **Set up alerting**
  ```yaml
  # Configure Alertmanager receivers
  # Configure Grafana SMTP for notifications
  ```

- [ ] **Enable TLS for Ingress**
  ```yaml
  # Add cert-manager annotations
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  ```

- [ ] **Configure backup strategy**
  - Prometheus snapshots
  - Grafana dashboard backups
  - PVC backups

- [ ] **Set resource limits appropriately**
  - Based on cluster size and metrics volume
  - Monitor and adjust as needed

- [ ] **Configure retention policies**
  - Prometheus: 30d (default)
  - Loki: 30d (default)
  - Adjust based on storage capacity

---

## 📚 Next Steps

1. **Add Service Monitors** for your applications
2. **Create Custom Dashboards** for your services
3. **Set up Alert Rules** for critical metrics
4. **Configure Notification Channels** (Slack, PagerDuty, etc.)
5. **Document Runbooks** for common alerts
6. **Train Team** on using Grafana and LogQL

---

## 🆘 Support

For issues or questions:

1. Check [Troubleshooting Guide](./README.md#troubleshooting)
2. Review [ArgoCD Application Status](https://localhost:8080/applications)
3. Check component logs in monitoring namespace
4. Consult upstream documentation:
   - [Prometheus](https://prometheus.io/docs/)
   - [Loki](https://grafana.com/docs/loki/)
   - [Grafana](https://grafana.com/docs/grafana/)

---

**Deployment Time**: ~5-10 minutes  
**Initial Sync**: ~3-5 minutes per component  
**Ready to Use**: ~10-15 minutes total


