# Contract Testing and CI/CD

> **Purpose**: Automated contract testing strategies and CI/CD integration patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Preventing breaking changes from reaching production
- Automating contract validation in pull request workflows
- Building quality gates in deployment pipelines
- Establishing contract testing as part of the development workflow

## Testing Pyramid for Data Contracts

```
         /\
        /  \     Contract Compatibility (diff)
       /    \    — Breaking change detection
      /------\
     /        \  Schema Validation (lint)
    /          \ — Syntax, types, required fields
   /------------\
  /              \ Data Quality (test)
 /                \— Row counts, nulls, ranges, freshness
/------------------\
```

## Contract Linting

Validate contract syntax and completeness without data access.

```bash
# datacontract-cli lint
datacontract lint datacontract.yaml

# Checks:
# - Valid YAML syntax
# - Required sections present (id, info, schema)
# - Field types are valid
# - References resolve
# - No duplicate field names
```

### Custom Lint Rules

```python
# custom_lint.py
import yaml

def lint_contract(path: str) -> list[str]:
    """Validate organizational contract standards."""
    errors = []
    contract = yaml.safe_load(open(path))

    # Require owner
    if "team" not in contract or "owner" not in contract.get("team", {}):
        errors.append("Missing team.owner")

    # Require SLA
    if "sla" not in contract:
        errors.append("Missing SLA section")

    # Require version
    info = contract.get("info", {})
    if "version" not in info:
        errors.append("Missing info.version")

    # Require descriptions on all fields
    for field in contract.get("schema", []):
        if "description" not in field:
            errors.append(f"Field '{field['name']}' missing description")

    return errors
```

## Breaking Change Detection

Detect breaking changes by diffing contract versions.

```bash
# Compare current branch vs main
datacontract diff \
  <(git show main:contracts/orders.yaml) \
  contracts/orders.yaml

# Output:
# BREAKING: Field 'customer_name' removed from orders
# BREAKING: Field 'amount' type changed from decimal to string
# MINOR: Field 'shipping_method' added (optional)
# PATCH: Description updated for 'order_id'
```

### Programmatic Diff

```python
from datacontract.diff import diff_contracts

changes = diff_contracts("v1.yaml", "v2.yaml")

breaking = [c for c in changes if c.severity == "BREAKING"]
if breaking:
    print(f"Found {len(breaking)} breaking changes:")
    for change in breaking:
        print(f"  - {change.description}")
    raise SystemExit(1)
```

## GitHub Actions Workflow

```yaml
# .github/workflows/contract-check.yml
name: Data Contract CI

on:
  pull_request:
    paths:
      - 'contracts/**'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install datacontract-cli
        run: pip install datacontract-cli

      - name: Lint all contracts
        run: |
          for f in contracts/*.yaml; do
            echo "Linting $f..."
            datacontract lint "$f"
          done

  breaking-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install datacontract-cli
        run: pip install datacontract-cli

      - name: Check for breaking changes
        run: |
          for f in contracts/*.yaml; do
            if git show main:"$f" > /dev/null 2>&1; then
              echo "Diffing $f..."
              datacontract diff <(git show main:"$f") "$f" \
                --fail-on breaking
            fi
          done

  test:
    runs-on: ubuntu-latest
    needs: [lint]
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: pip install datacontract-cli soda-core-snowflake

      - name: Test contracts against staging
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
        run: |
          for f in contracts/*.yaml; do
            echo "Testing $f..."
            datacontract test "$f" --server staging
          done
```

## Testing Strategy by Environment

| Environment | Tests | Frequency |
|-------------|-------|-----------|
| **Local/Dev** | Lint, schema validation | Every save (pre-commit) |
| **PR/CI** | Lint + breaking change diff | Every pull request |
| **Staging** | Lint + diff + data quality tests | Every merge to main |
| **Production** | Full contract tests + SLA monitoring | Continuous |

## See Also

- [datacontract-cli](datacontract-cli.md)
- [Pipeline Enforcement](pipeline-enforcement.md)
- [Versioning](../concepts/versioning.md)
