# Comind-Ops Platform

Complete cloud-native platform built on Kubernetes, featuring automated GitOps workflows, comprehensive observability, and enterprise-grade security. The Comind-Ops Platform provides everything you need to deploy, manage, and scale applications in both local development and cloud environments.

## ✨ Key Features

- **🏗️ Multi-Environment Support**: Seamless deployment across local (k3d), AWS, and DigitalOcean
- **🚀 GitOps Automation**: ArgoCD-powered continuous deployment with ApplicationSets  
- **🔒 Enterprise Security**: Sealed secrets, RBAC, network policies, and Pod Security Standards
- **📊 Complete Observability**: Prometheus monitoring, centralized logging, and health checks
- **🛠️ Developer Experience**: One-command app scaffolding, automated infrastructure provisioning
- **📦 Platform Services**: PostgreSQL, MinIO, Redis, ElasticMQ, Docker Registry with automated backups
- **🎯 Production Ready**: High availability, disaster recovery, security scanning, and compliance

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone git@github.com:comind-pro/comind-ops.git
cd comind-ops

# 2. Bootstrap the platform (one command setup!)
make bootstrap

# 3. Access ArgoCD dashboard
make argo-login

# 4. Create your first application with infrastructure
make new-app-full APP=my-api TEAM=backend

# 5. Deploy the infrastructure
make tf-apply-app APP=my-api
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     COMIND-OPS PLATFORM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   DEVELOPMENT   │  │     STAGING     │  │   PRODUCTION    │  │
│  │                 │  │                 │  │                 │  │
│  │ • Local k3d     │  │ • AWS/DO K8s    │  │ • AWS/DO K8s    │  │
│  │ • Fast iteration│  │ • Prod-like     │  │ • High-available│  │
│  │ • Debug friendly│  │ • Performance   │  │ • Disaster recovery│ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    PLATFORM SERVICES                        │ │
│  │                                                             │ │
│  │ ArgoCD • Sealed Secrets • Ingress • MetalLB • Prometheus   │ │
│  │ PostgreSQL • MinIO • Redis • ElasticMQ • Docker Registry   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   AUTOMATION    │  │    SECURITY     │  │   OBSERVABILITY │  │
│  │                 │  │                 │  │                 │  │
│  │ • Terraform     │  │ • RBAC          │  │ • Metrics       │  │
│  │ • Helm Charts   │  │ • Network Policies│ │ • Logs          │  │
│  │ • Scripts       │  │ • Pod Security  │  │ • Tracing       │  │
│  │ • CI/CD         │  │ • Secrets Mgmt  │  │ • Alerting      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🛠 Technologies

* **Terraform**: Infrastructure provisioning (clusters, networks, databases, registry).
* **Docker**: Local base services (Postgres, MinIO).
* **Kubernetes**: k3d/kind locally; EKS/DigitalOcean in the cloud.
* **Helm**: Deploy core services (ingress-nginx, Argo CD, cert-manager, sealed-secrets, monitoring stack).
* **Argo CD + ApplicationSet**: GitOps engine for apps and infrastructure.
* **Sealed Secrets**: Git-based encrypted secrets.
* **ElasticMQ**: SQS-compatible queue service.
* **MinIO**: S3-compatible object storage.
* **Postgres**: Relational database.
* **Docker Registry (distribution v2)**: Private container registry with retention policies.
* **regclient/regctl** or **crane**: Tools for registry cleanup automation.
* **Makefile + scripts**: Developer-friendly automation.

---

## 📂 Repository Structure

```
cloud-setup/
  docs/
    infra-architecture.md
    secrets.md
    onboarding.md
  apps.yaml
  infra/
    terraform/
      core/               # cluster creation, ingress, Argo, sealed-secrets, metallb
      modules/
        app_skel/
      states/             # local tfstate (ignored in git)
      envs/
        dev/platform/     # platform apps (redis, elasticmq, registry)
        stage/platform/
        prod/platform/
  k8s/
    base/                 # namespaces, quotas, policies
    platform/
      elasticmq/
      registry/
      backups/
    apps/
      <app-name>/
        chart/
        values/{dev,stage,prod}.yaml
        secrets/{dev,stage,prod}.sealed.yaml
        terraform/
  argo/
    argocd/install/
    apps/applicationset.yaml
  scripts/
    new-app.sh
    seal-secret.sh
    tf.sh
  .gitignore
  Makefile
```

---

## 🚀 Scenarios

### Local Development (Docker + k3d)

* Terraform provisions k3d cluster, Postgres & MinIO in Docker, installs ingress-nginx, Argo CD, sealed-secrets.
* Argo CD applies ApplicationSet from `apps.yaml`.
* Platform services (ElasticMQ, Registry, Backup CronJobs) deployed as platform apps.
* External access via **nip.io/sslip.io** ingress.

### Cloud Deployment (AWS / DigitalOcean)

* Terraform provisions EKS/DO Kubernetes, VPC, subnets, SG, RDS/Postgres, S3/MinIO.
* Helm releases install ingress-nginx, Argo CD, sealed-secrets.
* Argo CD deploys apps with same GitOps workflow.
* DNS managed via Route53/DO, secrets managed with SealedSecrets.

---

## 🔒 Secrets Management

* **Sealed Secrets** encrypts Kubernetes Secrets.
* Only encrypted `*.sealed.yaml` stored in git.
* Workflow:

  1. Create a plain Secret locally.
  2. Encrypt with `kubeseal` into `.sealed.yaml`.
  3. Commit `.sealed.yaml`.
* Argo CD syncs and decrypts secrets into the cluster.

---

## 🌐 Namespaces & Platform Services

* Each app runs in its own namespace: `myapp-dev`, `myapp-stage`, `myapp-prod`.
* Platform services deployed per environment in `platform-<env>` namespace:

  * **ElasticMQ** (SQS-compatible queue).
  * **Local Docker Registry**.
  * **CronJobs** for Postgres & MinIO backups.

---

## 🌀 Adding a New Application

1. **Scaffold:**

   ```bash
   ./scripts/new-app.sh video-api
   ```

   Creates `k8s/apps/video-api/...`.

2. **Register in apps.yaml:**

   ```yaml
   apps:
     - name: video-api
       path: k8s/apps/video-api/chart
       namespace: video-api
       helm:
         values:
           - k8s/apps/video-api/values/{{env}}.yaml
           - k8s/apps/video-api/secrets/{{env}}.sealed.yaml
   ```

3. **Secrets:**

   ```bash
   kubectl create secret generic db-creds --from-literal=PASSWORD=123 --dry-run=client -o yaml > secret.yaml
   ./scripts/seal-secret.sh video-api dev secret.yaml
   git add k8s/apps/video-api/secrets/dev.sealed.yaml
   git commit -m "add secrets for video-api"
   ```

4. **Terraform for app (optional):**

   ```bash
   ./scripts/tf.sh dev video-api
   ```

5. Argo CD syncs → Application ready and exposed via Ingress.

---

## 🔁 Automated Backups

* **Postgres CronJob**: Runs `pg_dumpall`, compresses, uploads to MinIO.
* **MinIO CronJob**: Mirrors production buckets into timestamped backup prefixes.
* Retention handled by lifecycle rules or cleanup jobs.

---

## 📦 Local Docker Registry with Retention

* Deployment of `registry:2` with PVC storage.
* Ingress exposes registry (e.g., `registry.dev.127.0.0.1.nip.io`).
* Authentication via htpasswd SealedSecret.
* Retention CronJob uses `regctl` to delete old tags/images (keep N tags or by age).

---

## ✅ CI/CD Workflow

* CI builds/pushes images to registry.
* CI bumps Helm values (`values/dev.yaml`) with new tags (or use `argocd-image-updater`).
* Validation jobs:

  * `terraform fmt/validate`.
  * `helm lint`.
  * (Optional) `tflint/tfsec`, `kubectl kustomize`.
* Argo CD applies changes automatically.

---

## 🧩 Advantages

* Unified flow for **local and cloud** environments.
* GitOps-driven, minimal manual steps.
* Secrets secure with SealedSecrets.
* Automated backups for critical stateful services.
* Local Docker Registry enables CI/CD pipelines without external dependencies.
* ElasticMQ provides simple, AWS SQS-compatible queue system.

---

## 📖 Next Steps

* Bootstrap cluster with `make bootstrap`.
* Login to Argo CD with `make argo-login`.
* Add new apps with `make new-app APP=myapp`.
* Seal secrets with `make seal APP=myapp ENV=dev FILE=secret.yaml`.
* Run app Terraform (if any) with `make tf APP=myapp ENV=dev`.

After that, applications will be available externally via ingress domains.
