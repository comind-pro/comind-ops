# Terraform S3 Backend Configuration
# This file should be used with: terraform init -backend-config=backend.hcl

bucket         = "comind-ops-terraform-state"
key            = "aws/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "comind-ops-terraform-locks"
encrypt        = true

# Optional: Use KMS key for encryption
# kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"

# Optional: Enable versioning
# versioning = true

# Optional: Enable server-side encryption
# server_side_encryption_configuration {
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
