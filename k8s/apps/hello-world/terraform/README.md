# ${APP_NAME} Infrastructure

Terraform configuration for provisioning infrastructure for the ${APP_NAME} application.

## Usage

```bash
# Initialize and apply
cd k8s/apps/${APP_NAME}/terraform
terraform init
terraform plan
terraform apply

# Get application information
terraform output ${APP_NAME}_dev_info
```

## Access

- **Application URL**: http://${APP_NAME}.dev.127.0.0.1.nip.io:${PORT}

## Features

This configuration provisions:
- Kubernetes namespace and RBAC
- Resource quotas and limits
- Network policies for security
- Integration with platform services
