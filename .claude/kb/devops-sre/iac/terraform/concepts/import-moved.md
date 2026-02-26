# Import, Moved, and Removed Blocks

> **Purpose**: Declarative resource lifecycle management for refactoring and adoption
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19
> **Since**: Import (1.5+), Moved (1.1+), Removed (1.7+)

## Overview

These blocks handle resource lifecycle transitions without destroying infrastructure: importing existing resources, renaming/moving resources, and removing resources from management.

## Import Blocks (1.5+)

Bring existing infrastructure under Terraform management declaratively (replaces `terraform import` CLI).

```hcl
# Basic import
import {
  to = aws_s3_bucket.data
  id = "my-existing-data-bucket"
}
resource "aws_s3_bucket" "data" { bucket = "my-existing-data-bucket" }

# GCP import (id format: "project/resource-name")
import {
  to = google_storage_bucket.uploads
  id = "my-project/uploads-bucket"
}

# Bulk import with for_each
import {
  for_each = toset(["bucket-a", "bucket-b", "bucket-c"])
  to       = aws_s3_bucket.legacy[each.key]
  id       = each.value
}
```

### Generate Configuration

```bash
# Write import block only (no resource block), then:
terraform plan -generate-config-out=generated.tf
# Review generated.tf, clean up, move to proper files, remove import block
```

## Moved Blocks (1.1+)

Rename or reorganize resources without destroy/recreate. Terraform updates state automatically.

```hcl
# Rename a resource
moved { from = aws_instance.web; to = aws_instance.app_server }

# Move into a module
moved { from = aws_s3_bucket.data; to = module.storage.aws_s3_bucket.data }

# Convert count to for_each
moved { from = aws_subnet.private[0]; to = aws_subnet.private["us-east-1a"] }
moved { from = aws_subnet.private[1]; to = aws_subnet.private["us-east-1b"] }

# Move between modules
moved { from = module.old_network.aws_vpc.main; to = module.new_network.aws_vpc.main }
```

## Removed Blocks (1.7+)

Stop managing a resource without destroying it. Replaces `terraform state rm`.

```hcl
# Keep resource, stop managing
removed { from = aws_s3_bucket.legacy_logs; lifecycle { destroy = false } }

# Destroy and remove
removed { from = aws_instance.temp_worker; lifecycle { destroy = true } }
```

## Workflow: Adopting Existing Infrastructure

1. Write import blocks for existing resources
2. `terraform plan -generate-config-out=generated.tf`
3. Review and clean up generated config
4. `terraform apply` (imports into state)
5. Remove import blocks (one-time operation)

## Decision Matrix

| Scenario | Block | Example |
|----------|-------|---------|
| Adopt existing infra | `import` | Bring S3 bucket under management |
| Rename resource | `moved` | `web` to `app_server` |
| Refactor into modules | `moved` | Root resource to module resource |
| Switch count to for_each | `moved` | `[0]` to `["key"]` |
| Stop managing resource | `removed` | Legacy resource, keep running |
| Delete and stop managing | `removed` | Temp resource, destroy it |

## Best Practices

| Practice | Why |
|----------|-----|
| Remove `import` blocks after apply | One-time operations |
| Keep `moved` blocks one release cycle | Consumers need time to update |
| Default to `destroy = false` in `removed` | Safer default |
| Test imports with `terraform plan` first | Verify before modifying state |

## Related

- [Resources](./resources.md) | [State](./state.md) | [Modules](./modules.md)
