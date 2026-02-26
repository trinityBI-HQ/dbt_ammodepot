# Multi-Environment Setup

> **Purpose**: Manage Airbyte configurations across dev, staging, and production environments
> **MCP Validated**: 2026-02-19

## When to Use

- Separate development, staging, and production data pipelines
- Test configuration changes before production deployment
- Isolate teams or projects with different requirements
- Implement promotion workflows (dev → staging → prod)
- Maintain environment parity while allowing differences

## Implementation

### Directory Structure

```
airbyte-config/
├── environments/
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── source-postgres/
│   │   ├── main.tf
│   │   └── variables.tf
│   └── connection/
│       ├── main.tf
│       └── variables.tf
├── main.tf
├── variables.tf
└── README.md
```

### Environment-Specific Variables

```hcl
# environments/dev/terraform.tfvars
environment       = "dev"
workspace_id      = "dev-workspace-uuid"

# Source configuration
postgres_host     = "dev-db.internal.example.com"
postgres_database = "dev_application"
postgres_user     = "airbyte_dev"

# Destination configuration
snowflake_account  = "dev-account"
snowflake_database = "DEV_ANALYTICS"
snowflake_schema   = "RAW"
snowflake_warehouse = "DEV_WH"

# Sync schedule (less frequent in dev)
sync_schedule = "0 */12 * * *"  # Every 12 hours

# environments/prod/terraform.tfvars
environment       = "prod"
workspace_id      = "prod-workspace-uuid"

postgres_host     = "prod-db.internal.example.com"
postgres_database = "production"
postgres_user     = "airbyte_readonly"

snowflake_account  = "prod-account"
snowflake_database = "PROD_ANALYTICS"
snowflake_schema   = "RAW"
snowflake_warehouse = "PROD_WH"

# More frequent in prod
sync_schedule = "0 */2 * * *"  # Every 2 hours
```

### Main Terraform Configuration

```hcl
# main.tf
variable "environment" {}
variable "workspace_id" {}
variable "postgres_host" {}
variable "postgres_database" {}
variable "snowflake_database" {}
variable "sync_schedule" {}

# Postgres source module
module "postgres_source" {
  source = "./modules/source-postgres"

  name         = "${var.environment}-postgres"
  workspace_id = var.workspace_id
  host         = var.postgres_host
  database     = var.postgres_database
  username     = var.postgres_user
  password     = var.postgres_password
}

# Snowflake destination module
module "snowflake_destination" {
  source = "./modules/destination-snowflake"

  name         = "${var.environment}-snowflake"
  workspace_id = var.workspace_id
  account      = var.snowflake_account
  database     = var.snowflake_database
  schema       = var.snowflake_schema
  warehouse    = var.snowflake_warehouse
  username     = var.snowflake_user
  password     = var.snowflake_password
}

# Connection module
module "customer_sync" {
  source = "./modules/connection"

  name           = "${var.environment}-customers-sync"
  source_id      = module.postgres_source.source_id
  destination_id = module.snowflake_destination.destination_id
  schedule       = var.sync_schedule

  streams = [
    {
      name         = "customers"
      sync_mode    = "incremental_append_deduped"
      cursor_field = ["updated_at"]
      primary_key  = [["customer_id"]]
    }
  ]
}
```

## Remote State per Environment

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "airbyte/dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "airbyte/prod/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Configuration

| Environment | Purpose | Data Volume | Sync Frequency | Users |
|-------------|---------|-------------|----------------|-------|
| **Dev** | Development, testing | Sample data | 12-24 hours | Engineers |
| **Staging** | Pre-production validation | Recent subset | 6 hours | QA + Engineers |
| **Prod** | Production workloads | Full dataset | 2-6 hours | All stakeholders |

## Secret Management per Environment

```hcl
# Use AWS Secrets Manager with environment prefix
data "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = "airbyte/${var.environment}/postgres/password"
}

data "aws_secretsmanager_secret_version" "snowflake_password" {
  secret_id = "airbyte/${var.environment}/snowflake/password"
}

# Or use environment-specific tfvars
# Export before terraform apply:
# export TF_VAR_postgres_password=$(aws secretsmanager get-secret-value \
#   --secret-id airbyte/dev/postgres/password --query SecretString --output text)
```

## Workspace Separation

### Option 1: Separate Airbyte Instances

```yaml
# Dev Airbyte instance
airbyte_dev:
  url: https://dev-airbyte.example.com
  workspaces:
    - name: dev-workspace

# Prod Airbyte instance
airbyte_prod:
  url: https://prod-airbyte.example.com
  workspaces:
    - name: prod-workspace
```

### Option 2: Shared Instance with Multiple Workspaces

```hcl
# Single Airbyte instance, multiple workspaces
provider "airbyte" {
  bearer_auth = var.airbyte_api_key
  server_url  = "https://cloud.airbyte.com/api"
}

# Dev workspace
data "airbyte_workspace" "dev" {
  workspace_id = "dev-workspace-uuid"
}

# Prod workspace
data "airbyte_workspace" "prod" {
  workspace_id = "prod-workspace-uuid"
}
```

## Promotion Workflow

```bash
#!/bin/bash
# scripts/promote.sh - Promote config from staging to prod

set -e

ENV_FROM=${1:-staging}
ENV_TO=${2:-prod}

echo "Promoting Airbyte config from $ENV_FROM to $ENV_TO"

# 1. Plan staging changes
cd environments/$ENV_FROM
terraform plan -out=tfplan

# 2. Review and apply
terraform apply tfplan

# 3. Extract configurations
terraform output -json > ../$ENV_TO/config_to_promote.json

# 4. Review production plan
cd ../prod
terraform plan -var-file=terraform.tfvars

# 5. Manual approval (or use CI/CD)
read -p "Apply to production? (yes/no): " confirm
if [ "$confirm" == "yes" ]; then
    terraform apply -var-file=terraform.tfvars
fi
```

## Example Usage

```bash
# Deploy to dev
cd environments/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Deploy to staging
cd ../staging
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Deploy to prod (with approval)
cd ../prod
terraform init
terraform plan -var-file=terraform.tfvars
# Review changes carefully
terraform apply -var-file=terraform.tfvars
```

## CI/CD Pipeline

```yaml
# .github/workflows/airbyte-deploy.yml
name: Deploy Airbyte Config

on:
  push:
    branches:
      - main
    paths:
      - 'airbyte-config/**'

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2

      - name: Deploy to Dev
        working-directory: airbyte-config/environments/dev
        env:
          TF_VAR_postgres_password: ${{ secrets.DEV_POSTGRES_PASSWORD }}
          TF_VAR_snowflake_password: ${{ secrets.DEV_SNOWFLAKE_PASSWORD }}
        run: |
          terraform init
          terraform apply -var-file=terraform.tfvars -auto-approve

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging
        working-directory: airbyte-config/environments/staging
        env:
          TF_VAR_postgres_password: ${{ secrets.STAGING_POSTGRES_PASSWORD }}
        run: |
          terraform init
          terraform apply -var-file=terraform.tfvars -auto-approve

  deploy-prod:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - name: Deploy to Production
        working-directory: airbyte-config/environments/prod
        env:
          TF_VAR_postgres_password: ${{ secrets.PROD_POSTGRES_PASSWORD }}
        run: |
          terraform init
          terraform apply -var-file=terraform.tfvars -auto-approve
```

## Environment Comparison

```bash
# scripts/compare-environments.sh
#!/bin/bash

echo "Comparing dev and prod configurations..."

diff \
  <(cd environments/dev && terraform state pull | jq '.resources | sort_by(.type, .name)') \
  <(cd environments/prod && terraform state pull | jq '.resources | sort_by(.type, .name)')
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Same workspace for all envs | Separate workspaces |
| Hardcode env-specific values | Use tfvars per env |
| Copy/paste configs | Use modules |
| Manual changes in prod | Everything via Terraform |
| Skip staging | Always test in staging first |

## See Also

- [terraform-orchestration](../patterns/terraform-orchestration.md)
- [cloud-vs-oss](../concepts/cloud-vs-oss.md)
- [connections](../concepts/connections.md)
