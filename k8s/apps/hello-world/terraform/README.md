# hello-world Infrastructure

Terraform configuration for provisioning infrastructure for the hello-world application.
Generated for profile: **local** (can be changed at runtime)

## Usage

### Local Development (k3d)
```bash
# Using make commands (recommended)
make tf-init-app APP=hello-world
make tf-apply-app APP=hello-world PROFILE=local

# Or using tf.sh directly
./scripts/tf.sh dev hello-world init --profile local
./scripts/tf.sh dev hello-world apply --profile local

# Get application information
make tf-output APP=hello-world PROFILE=local
```

### AWS Production (EKS)
```bash
# Using make commands (recommended)
make tf-init-app APP=hello-world PROFILE=aws
make tf-apply-app APP=hello-world PROFILE=aws

# Or using tf.sh directly
./scripts/tf.sh dev hello-world init --profile aws
./scripts/tf.sh dev hello-world apply --profile aws

# Get application information
make tf-output APP=hello-world PROFILE=aws
```

## Access URLs

- **Local**: http://hello-world.dev.127.0.0.1.nip.io:8080
- **AWS**: https://hello-world.dev.your-domain.com

## Features

This configuration provisions:
- Kubernetes namespace and RBAC
- Resource quotas and limits
- Network policies for security
- Integration with platform services
- Profile-specific monitoring (Prometheus for AWS only)

## Generated Configuration

- **Team**: platform
- **Language**: generic
- **Default Profile**: local
- **Features**: Database=true, Cache=false, Queue=true
