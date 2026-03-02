# Multi-Environment Setup

> **Purpose**: Manage Airbyte configurations across dev, staging, and production environments
> **MCP Validated**: 2026-02-19

## When to Use

- Separate development, staging, and production data pipelines
- Test configuration changes before production deployment
- Implement promotion workflows (dev -> staging -> prod)

## Implementation

### Directory Structure

```
airbyte-config/
├── environments/
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
├── modules/
│   ├── source-postgres/
│   └── connection/
├── main.tf
└── variables.tf
```

### Environment-Specific Variables

```hcl
# environments/dev/terraform.tfvars
environment        = "dev"
workspace_id       = "dev-workspace-uuid"
postgres_host      = "dev-db.internal.example.com"
postgres_database  = "dev_application"
snowflake_database = "DEV_ANALYTICS"
snowflake_warehouse = "DEV_WH"
sync_schedule      = "0 */12 * * *"

# environments/prod/terraform.tfvars
environment        = "prod"
workspace_id       = "prod-workspace-uuid"
postgres_host      = "prod-db.internal.example.com"
postgres_database  = "production"
snowflake_database = "PROD_ANALYTICS"
snowflake_warehouse = "PROD_WH"
sync_schedule      = "0 */2 * * *"
```

### Main Terraform Configuration

```hcl
variable "environment" {}
variable "workspace_id" {}
variable "postgres_host" {}
variable "snowflake_database" {}
variable "sync_schedule" {}

module "postgres_source" {
  source       = "./modules/source-postgres"
  name         = "${var.environment}-postgres"
  workspace_id = var.workspace_id
  host         = var.postgres_host
  database     = var.postgres_database
  password     = var.postgres_password
}

module "snowflake_destination" {
  source       = "./modules/destination-snowflake"
  name         = "${var.environment}-snowflake"
  workspace_id = var.workspace_id
  database     = var.snowflake_database
  warehouse    = var.snowflake_warehouse
}

module "customer_sync" {
  source         = "./modules/connection"
  name           = "${var.environment}-customers-sync"
  source_id      = module.postgres_source.source_id
  destination_id = module.snowflake_destination.destination_id
  schedule       = var.sync_schedule
  streams = [{
    name = "customers", sync_mode = "incremental_append_deduped",
    cursor_field = ["updated_at"], primary_key = [["customer_id"]]
  }]
}
```

## Configuration

| Environment | Data Volume | Sync Frequency | Users |
|-------------|-------------|----------------|-------|
| **Dev** | Sample data | 12-24 hours | Engineers |
| **Staging** | Recent subset | 6 hours | QA + Engineers |
| **Prod** | Full dataset | 2-6 hours | All stakeholders |

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
```

## Secret Management

```hcl
data "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = "airbyte/${var.environment}/postgres/password"
}
```

## Workspace Separation

**Option 1 - Separate Instances**: Different Airbyte URLs per environment (dev-airbyte.example.com, prod-airbyte.example.com).
**Option 2 - Shared Instance**: Single Airbyte with multiple workspaces, selected by `workspace_id` variable.

## Promotion Workflow

```bash
# Deploy per environment
cd environments/dev && terraform init && terraform apply -var-file=terraform.tfvars
cd ../staging && terraform init && terraform apply -var-file=terraform.tfvars
cd ../prod && terraform init && terraform plan -var-file=terraform.tfvars  # Review first
```

## CI/CD Pipeline

```yaml
# .github/workflows/airbyte-deploy.yml
on:
  push:
    branches: [main]
    paths: ['airbyte-config/**']

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init && terraform apply -var-file=terraform.tfvars -auto-approve
        working-directory: airbyte-config/environments/dev

  deploy-prod:
    needs: deploy-dev
    environment: production  # Manual approval
    runs-on: ubuntu-latest
    steps:
      - run: terraform init && terraform apply -var-file=terraform.tfvars -auto-approve
        working-directory: airbyte-config/environments/prod
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Same workspace for all envs | Separate workspaces |
| Hardcode env-specific values | Use tfvars per env |
| Copy/paste configs | Use Terraform modules |
| Manual changes in prod | Everything via Terraform |

## See Also

- [terraform-orchestration](../patterns/terraform-orchestration.md)
- [cloud-vs-oss](../concepts/cloud-vs-oss.md)
- [connections](../concepts/connections.md)
