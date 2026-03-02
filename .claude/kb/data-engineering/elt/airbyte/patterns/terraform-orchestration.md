# Terraform Orchestration

> **Purpose**: Manage Airbyte infrastructure as code with Terraform provider
> **MCP Validated**: 2026-02-19

## When to Use

- Infrastructure as Code for Airbyte configurations
- Multi-environment deployment (dev/staging/prod)
- Version control for connections, sources, destinations
- CI/CD pipelines for Airbyte config changes

## Implementation

```hcl
terraform {
  required_providers {
    airbyte = {
      source  = "airbytehq/airbyte"
      version = "~> 0.18.0"
    }
  }
}

provider "airbyte" {
  bearer_auth = var.airbyte_api_key
  # server_url = "http://localhost:8001/api"  # For OSS
}

resource "airbyte_source_postgres" "production_db" {
  name         = "Production Postgres"
  workspace_id = var.workspace_id
  configuration = {
    host     = "prod-db.example.com"
    port     = 5432
    database = "production"
    username = "airbyte_readonly"
    password = var.postgres_password
    ssl_mode = { mode = "require" }
    replication_method = {
      method = "CDC"
      plugin = "pgoutput"
      replication_slot = "airbyte_slot"
      publication      = "airbyte_publication"
    }
    schemas = ["public", "analytics"]
  }
}

resource "airbyte_destination_snowflake" "data_warehouse" {
  name         = "Snowflake DW"
  workspace_id = var.workspace_id
  configuration = {
    host      = "account.snowflakecomputing.com"
    role      = "AIRBYTE_ROLE"
    warehouse = "AIRBYTE_WH"
    database  = "ANALYTICS"
    schema    = "RAW"
    username  = "AIRBYTE_USER"
    credentials = { password = var.snowflake_password }
  }
}

resource "airbyte_connection" "postgres_to_snowflake" {
  name                 = "Postgres -> Snowflake"
  source_id            = airbyte_source_postgres.production_db.source_id
  destination_id       = airbyte_destination_snowflake.data_warehouse.destination_id
  namespace_definition = "destination"
  namespace_format     = "raw"
  prefix               = "postgres_"
  schedule = {
    schedule_type   = "cron"
    cron_expression = "0 */6 * * *"
  }
  configurations = {
    streams = [
      { name = "users", sync_mode = "incremental_append_deduped",
        cursor_field = ["updated_at"], primary_key = [["id"]] },
      { name = "orders", sync_mode = "incremental_append_deduped",
        cursor_field = ["updated_at"], primary_key = [["order_id"]] },
      { name = "products", sync_mode = "full_refresh_overwrite" }
    ]
  }
}
```

## Configuration

| Setting | Description |
|---------|-------------|
| `bearer_auth` | Airbyte Cloud API key (required for Cloud) |
| `server_url` | OSS API endpoint (default: `http://localhost:8001/api`) |
| `workspace_id` | Target workspace UUID |

## Multi-Environment Pattern

```hcl
# environments/dev/terraform.tfvars
workspace_id       = "dev-workspace-uuid"
postgres_host      = "dev-db.example.com"
snowflake_database = "DEV_ANALYTICS"
sync_schedule      = "0 */12 * * *"

# environments/prod/terraform.tfvars
workspace_id       = "prod-workspace-uuid"
postgres_host      = "prod-db.example.com"
snowflake_database = "PROD_ANALYTICS"
sync_schedule      = "0 */2 * * *"
```

## State and Secret Management

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "airbyte/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

data "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = "airbyte/postgres/password"
}
```

## Module Pattern

```hcl
# modules/airbyte-connection/main.tf
variable "source_id" {}
variable "destination_id" {}
variable "streams" {}

resource "airbyte_connection" "this" {
  source_id      = var.source_id
  destination_id = var.destination_id
  configurations = { streams = var.streams }
}

# Usage
module "customer_sync" {
  source         = "./modules/airbyte-connection"
  source_id      = airbyte_source_postgres.db.source_id
  destination_id = airbyte_destination_snowflake.dw.destination_id
  streams = [{
    name = "customers", sync_mode = "incremental_append_deduped",
    cursor_field = ["updated_at"], primary_key = [["customer_id"]]
  }]
}
```

## CI/CD Integration

```yaml
# .github/workflows/airbyte-deploy.yml
on:
  push:
    branches: [main]
    paths: ['terraform/airbyte/**']
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init && terraform plan -out=tfplan
        working-directory: terraform/airbyte
        env:
          TF_VAR_airbyte_api_key: ${{ secrets.AIRBYTE_API_KEY }}
      - run: terraform apply -auto-approve tfplan
        if: github.ref == 'refs/heads/main'
        working-directory: terraform/airbyte
```

## Import Existing Resources

```bash
terraform import airbyte_source_postgres.production_db source-uuid
terraform import airbyte_connection.postgres_to_snowflake connection-uuid
terraform state show airbyte_source_postgres.production_db
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode secrets in .tf files | Use variables + secret managers |
| Skip state locking | Remote backend with DynamoDB locking |
| One giant main.tf | Modularize by domain/team |
| No version pinning | Pin provider versions |

## See Also

- [connections](../concepts/connections.md)
- [multi-environment-setup](../patterns/multi-environment-setup.md)
- [airbyte-api](../concepts/airbyte-api.md)
