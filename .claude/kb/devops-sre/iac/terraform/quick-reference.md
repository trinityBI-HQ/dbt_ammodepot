# Terraform Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19 | **Version**: 1.14.x

## Essential Commands

| Command | Purpose |
|---------|---------|
| `terraform init` | Initialize, download providers |
| `terraform plan` | Preview changes |
| `terraform apply` | Apply changes |
| `terraform destroy` | Remove all managed resources |
| `terraform fmt` | Format files |
| `terraform validate` | Check syntax |
| `terraform test` | Run native tests (1.6+) |
| `terraform stacks` | Manage stack deployments (1.13+) |

## Import & State Commands

| Command | Purpose |
|---------|---------|
| `terraform plan -generate-config-out=gen.tf` | Generate config for imports |
| `terraform state list` | List resources in state |
| `terraform state mv` | Move resource in state |
| `terraform state rm` | Remove from state (keeps infra) |

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Resource definitions |
| `variables.tf` / `outputs.tf` | Inputs and outputs |
| `providers.tf` / `versions.tf` | Provider config and version pins |
| `backend.tf` | Remote state configuration |
| `*.tftest.hcl` | Test files (1.6+) |

## Variable Types

| Type | Example |
|------|---------|
| `string` / `number` / `bool` | `"us-central1"` / `100` / `true` |
| `list(string)` / `set(string)` | `["a", "b"]` |
| `map(string)` / `object({})` | `{key = "value"}` |
| `optional(string, "default")` | Optional with default |

## Modern Blocks

```hcl
# Import existing resource (1.5+)
import { to = aws_s3_bucket.existing; id = "bucket-name" }

# Rename/move without destroy (1.1+)
moved { from = aws_instance.old; to = aws_instance.new }

# Stop managing without destroy (1.7+)
removed { from = aws_s3_bucket.old; lifecycle { destroy = false } }

# Ephemeral resource - not persisted in state (1.10+)
ephemeral "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
}

# Ephemeral variable (1.10+)
variable "api_token" { type = string; ephemeral = true }

# Write-only argument - flows ephemeral into managed resource (1.11+)
resource "aws_db_instance" "main" {
  password = ephemeral.aws_secretsmanager_secret_version.db.secret_string  # write-only
}

# Terraform Actions - imperative Day 2 ops (1.14+)
action "invoke" {
  resource = aws_lambda_function.processor  # invoke Lambda, stop EC2, etc.
}
```

## Version Highlights (1.10 - 1.14)

| Version | Key Feature |
|---------|-------------|
| 1.10 | Ephemeral values (secrets not in state), parallel tests |
| 1.11 | Write-only arguments, test improvements |
| 1.13 | `terraform stacks` CLI, `rpcapi` GA, better errors |
| 1.14 | Terraform Actions (Day 2 ops) |

## Decision Matrix

| Need | Choose |
|------|--------|
| Secrets not in state | Ephemeral variables/resources (1.10+) |
| Day 2 operations | Terraform Actions (1.14+) |
| Multi-workspace deploy | Terraform Stacks |
| Multiple environments | Workspaces or directory structure |
| Reusable components | Modules |
| Existing infra | `import` blocks |
| Rename resources | `moved` blocks |

## Related: [index.md](index.md)
