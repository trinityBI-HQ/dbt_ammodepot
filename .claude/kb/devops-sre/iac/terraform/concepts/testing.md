# Testing

> **Purpose**: Native test framework for validating Terraform modules
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19
> **Since**: Terraform 1.6+

## Overview

Terraform's native test framework (`terraform test`) validates modules with `.tftest.hcl` files containing `run` blocks with assertions. Tests can execute `plan` or `apply` against real or mock providers.

## Test File Structure

```text
modules/s3-bucket/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── defaults.tftest.hcl
    └── encryption.tftest.hcl
```

## Basic Test

```hcl
# tests/defaults.tftest.hcl
variables {
  bucket_name = "test-bucket"
  environment = "test"
}

run "creates_bucket_with_correct_name" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "test-bucket"
    error_message = "Bucket name did not match expected"
  }
}
```

## Plan vs Apply Tests

```hcl
# Plan-only (fast, no real resources)
run "validates_configuration" {
  command = plan
  assert {
    condition     = aws_lambda_function.this.runtime == "python3.12"
    error_message = "Expected Python 3.12 runtime"
  }
}

# Apply (creates real resources, then destroys)
run "deploys_successfully" {
  command = apply
  assert {
    condition     = output.bucket_arn != ""
    error_message = "Bucket ARN should not be empty"
  }
}
```

## Testing with Helper Modules

```hcl
run "setup_vpc" {
  module { source = "./tests/setup" }
}

run "deploy_lambda" {
  variables {
    vpc_id    = run.setup_vpc.vpc_id
    subnet_id = run.setup_vpc.subnet_id
  }
  assert {
    condition     = aws_lambda_function.this.vpc_config[0].vpc_id != ""
    error_message = "Lambda should be in VPC"
  }
}
```

## Expected Failures

```hcl
run "rejects_invalid_environment" {
  command = plan
  variables { environment = "invalid" }
  expect_failures = [var.environment]
}
```

## Parallel Execution (1.10+)

```hcl
test { parallel = true }

run "test_a" { state_key = "a" }
run "test_b" { state_key = "b" }  # runs in parallel with test_a
```

## v1.11 Test Improvements

Terraform 1.11 (March 2025) added several test framework enhancements:

| Improvement | Description |
|-------------|-------------|
| **Better error output** | Clearer assertion failure messages with context |
| **Provider mocking** | Improved mock provider support for isolated tests |
| **Test ordering** | More predictable execution order for dependent tests |
| **Resource cleanup** | Improved destroy behavior after test failures |

## Running Tests

```bash
terraform test                                    # all tests
terraform test -filter=tests/defaults.tftest.hcl  # specific file
terraform test -verbose                           # detailed output
terraform test -json                              # CI output
```

## Best Practices

| Practice | Why |
|----------|-----|
| `command = plan` for unit tests | No real resources, instant feedback |
| `command = apply` sparingly | Slow, costs money, validates real behavior |
| `expect_failures` for edge cases | Verify validation rules work |
| Helper modules for setup | Keep tests DRY |
| `-json` in CI | Machine-parseable results |
| `parallel = true` (1.10+) | Faster test suites |

## Related

- [Modules](./modules.md) | [Variables](./variables.md) | [Resources](./resources.md)
