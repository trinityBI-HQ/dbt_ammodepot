# Terraform Orchestration

> **Purpose**: Manage Airbyte infrastructure as code with Terraform provider
> **MCP Validated**: 2026-02-19

## When to Use

- Infrastructure as Code for Airbyte configurations
- Multi-environment deployment (dev/staging/prod)
- Version control for connections and sources
- Automated testing and CI/CD pipelines
- Consistent deployments across teams

## Implementation

```hcl
# terraform/main.tf
terraform {
  required_providers {
    airbyte = {
      source  = "airbytehq/airbyte"
      version = "~> 0.18.0"
    }
  }
}

provider "airbyte" {
  # Cloud
  bearer_auth = var.airbyte_api_key

  # OSS (if self-hosted)
  # server_url = "http://localhost:8001/api"
}

# Define Postgres source
resource "airbyte_source_postgres" "production_db" {
  name         = "Production Postgres"
  workspace_id = var.workspace_id

  configuration = {
    host     = "prod-db.example.com"
    port     = 5432
    database = "production"
    username = "airbyte_readonly"
    password = var.postgres_password
    ssl_mode = {
      mode = "require"
    }
    replication_method = {
      method = "CDC"
      plugin = "pgoutput"
      replication_slot    = "airbyte_slot"
      publication         = "airbyte_publication"
      initial_waiting_seconds = 300
    }
    schemas = ["public", "analytics"]
  }
}

# Define Snowflake destination
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
    credentials = {
      password = var.snowflake_password
    }
  }
}

# Create connection
resource "airbyte_connection" "postgres_to_snowflake" {
  name              = "Postgres → Snowflake"
  source_id         = airbyte_source_postgres.production_db.source_id
  destination_id    = airbyte_destination_snowflake.data_warehouse.destination_id
  namespace_definition = "destination"
  namespace_format = "raw"
  prefix           = "postgres_"

  schedule = {
    schedule_type = "cron"
    cron_expression = "0 */6 * * *"  # Every 6 hours
  }

  configurations = {
    streams = [
      {
        name = "users"
        sync_mode = "incremental_append_deduped"
        cursor_field = ["updated_at"]
        primary_key  = [["id"]]
      },
      {
        name = "orders"
        sync_mode = "incremental_append_deduped"
        cursor_field = ["updated_at"]
        primary_key  = [["order_id"]]
      },
      {
        name = "products"
        sync_mode = "full_refresh_overwrite"
      }
    ]
  }
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `bearer_auth` | Required (Cloud) | Airbyte Cloud API key |
| `server_url` | `http://localhost:8001/api` | Airbyte OSS API endpoint |
| `workspace_id` | Required | Target workspace UUID |

## Multi-Environment Pattern

```hcl
# terraform/environments/dev/terraform.tfvars
workspace_id      = "dev-workspace-uuid"
postgres_host     = "dev-db.example.com"
snowflake_database = "DEV_ANALYTICS"
sync_schedule     = "0 */12 * * *"  # Every 12 hours

# terraform/environments/prod/terraform.tfvars
workspace_id      = "prod-workspace-uuid"
postgres_host     = "prod-db.example.com"
snowflake_database = "PROD_ANALYTICS"
sync_schedule     = "0 */2 * * *"   # Every 2 hours

# terraform/main.tf
variable "workspace_id" {}
variable "postgres_host" {}
variable "snowflake_database" {}
variable "sync_schedule" {}

resource "airbyte_source_postgres" "db" {
  workspace_id = var.workspace_id
  configuration = {
    host = var.postgres_host
    # ... other config
  }
}

resource "airbyte_connection" "conn" {
  schedule = {
    cron_expression = var.sync_schedule
  }
}
```

## Using Generic Resources

For robustness across connector version changes:

```hcl
# Use airbyte_source_custom instead of specific connector
resource "airbyte_source_custom" "generic_postgres" {
  name         = "Production Postgres"
  workspace_id = var.workspace_id
  source_definition_id = "decd338e-5647-4c0b-adf4-da0e75f5a750"  # Postgres

  configuration_json = jsonencode({
    host     = "prod-db.example.com"
    port     = 5432
    database = "production"
    username = "airbyte_readonly"
    password = var.postgres_password
    ssl_mode = {
      mode = "require"
    }
    replication_method = {
      method = "CDC"
      plugin = "pgoutput"
    }
  })
}
```

## State Management

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "airbyte/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Secret Management

```hcl
# Use AWS Secrets Manager
data "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = "airbyte/postgres/password"
}

resource "airbyte_source_postgres" "db" {
  configuration = {
    password = data.aws_secretsmanager_secret_version.postgres_password.secret_string
  }
}

# Or use environment variables
variable "postgres_password" {
  sensitive = true
}

# Export before terraform apply
# export TF_VAR_postgres_password="secret"
```

## CI/CD Integration

```yaml
# .github/workflows/airbyte-deploy.yml
name: Deploy Airbyte Config

on:
  push:
    branches: [main]
    paths:
      - 'terraform/airbyte/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        working-directory: terraform/airbyte
        run: terraform init

      - name: Terraform Plan
        working-directory: terraform/airbyte
        env:
          TF_VAR_airbyte_api_key: ${{ secrets.AIRBYTE_API_KEY }}
          TF_VAR_postgres_password: ${{ secrets.POSTGRES_PASSWORD }}
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        working-directory: terraform/airbyte
        run: terraform apply -auto-approve tfplan
```

## Import Existing Resources

```bash
# Import existing source
terraform import airbyte_source_postgres.production_db source-uuid

# Import existing connection
terraform import airbyte_connection.postgres_to_snowflake connection-uuid

# Generate configuration from import
terraform state show airbyte_source_postgres.production_db
```

## Example Usage

```bash
# Initialize Terraform
cd terraform/airbyte
terraform init

# Plan changes (dev environment)
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply (prod environment)
terraform apply -var-file=environments/prod/terraform.tfvars

# Destroy (cleanup)
terraform destroy -var-file=environments/dev/terraform.tfvars
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
  configurations = {
    streams = var.streams
  }
}

# terraform/main.tf
module "customer_sync" {
  source = "./modules/airbyte-connection"

  source_id      = airbyte_source_postgres.db.source_id
  destination_id = airbyte_destination_snowflake.dw.destination_id

  streams = [
    {
      name        = "customers"
      sync_mode   = "incremental_append_deduped"
      cursor_field = ["updated_at"]
      primary_key  = [["customer_id"]]
    }
  ]
}
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode secrets in .tf files | Use variables + secret managers |
| Skip state locking | Use remote backend with locking |
| One giant main.tf | Modularize by domain/team |
| Manual changes in UI | Everything as code |
| No version pinning | Pin provider versions |

## See Also

- [connections](../concepts/connections.md)
- [multi-environment-setup](../patterns/multi-environment-setup.md)
- [airbyte-api](../concepts/airbyte-api.md)
