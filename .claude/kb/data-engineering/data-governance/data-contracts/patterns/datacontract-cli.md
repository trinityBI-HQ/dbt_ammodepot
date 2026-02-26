# datacontract-cli

> **Purpose**: CLI tooling for creating, testing, linting, and managing data contracts (v0.11.4)
> **MCP Validated**: 2026-02-19

## When to Use

- Need a developer-friendly CLI for contract management
- Want to lint, test, and diff contracts in CI/CD
- Building contract-first data pipelines
- Need to export contracts to different formats (dbt, SQL, docs)

## Installation

```bash
pip install datacontract-cli

# Verify
datacontract version
# datacontract-cli v0.11.4
```

### v0.11.4 Changes

- **DuckDB is now optional**: No longer installed by default, reducing dependency size
- **Spark decimal precision**: Fixed precision handling for DecimalType fields
- **BigQuery improvements**: Better type mapping and connection handling
- **ODCS as default**: `datacontract init` now generates ODCS v3.1.2 format by default

## datacontract.yaml Format

```yaml
dataContractSpecification: 0.9.3
id: urn:datacontract:checkout:orders
info:
  title: Orders
  version: 1.0.0
  owner: checkout-team
  contact:
    name: Jane Doe
    email: jane@company.com

servers:
  production:
    type: snowflake
    account: company.snowflakecomputing.com
    database: ANALYTICS
    schema: CHECKOUT

models:
  orders:
    description: "Checkout orders"
    fields:
      order_id:
        type: string
        required: true
        unique: true
        primaryKey: true
      customer_id:
        type: string
        required: true
        references: customers.customer_id
      total_amount:
        type: decimal
        required: true
        minimum: 0
      status:
        type: string
        required: true
        enum: [pending, confirmed, shipped, delivered, cancelled]
      created_at:
        type: timestamp
        required: true

quality:
  type: SodaCL
  specification:
    checks for orders:
      - row_count > 0
      - duplicate_count(order_id) = 0
```

## CLI Commands

### Init — Create a new contract

```bash
datacontract init
# Creates datacontract.yaml with ODCS v3.1.2 template (default since v0.11)
```

### Lint — Validate contract syntax

```bash
datacontract lint datacontract.yaml
# Checks YAML syntax, required fields, type consistency
```

### Test — Run contract tests against data

```bash
# Test against a Snowflake server
datacontract test datacontract.yaml

# Test against specific server
datacontract test datacontract.yaml --server production

# Test with custom connection
datacontract test datacontract.yaml \
  --server production \
  --override-server-type snowflake \
  --override-server-account company.us-east-1
```

### Diff — Compare contract versions

```bash
datacontract diff v1/datacontract.yaml v2/datacontract.yaml

# Output:
# BREAKING: Field 'customer_name' removed from model 'orders'
# MINOR: Field 'shipping_method' added to model 'orders' (optional)
```

### Export — Convert to other formats

```bash
# Export to dbt schema.yml
datacontract export datacontract.yaml --format dbt

# Export to SQL DDL
datacontract export datacontract.yaml --format sql

# Export to HTML documentation
datacontract export datacontract.yaml --format html

# Export to JSON Schema
datacontract export datacontract.yaml --format jsonschema

# Export to Avro schema
datacontract export datacontract.yaml --format avro

# Export to Great Expectations suite
datacontract export datacontract.yaml --format great-expectations
```

### Import — Create contract from existing sources

```bash
datacontract import --format sql --source schema.sql      # From SQL
datacontract import --format dbt --source models/schema.yml  # From dbt
datacontract import --format avro --source schema.avsc     # From Avro
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `--server` | First defined | Target server for testing |
| `--format` | yaml | Export format |
| `--output` | stdout | Output file path |
| `--publish` | none | Publish URL for contract registry |

## Supported Servers

| Server Type | Connection |
|------------|------------|
| Snowflake | `account`, `database`, `schema` |
| BigQuery | `project`, `dataset` |
| Postgres | `host`, `port`, `database` |
| Databricks | `host`, `catalog`, `schema` |
| S3 / GCS | `path`, `format` (parquet, csv) |
| Kafka | `bootstrap_servers`, `topic` |
| Local files | `path`, `format` |

## CI/CD Integration

```yaml
# GitHub Actions
- name: Lint data contract
  run: datacontract lint datacontract.yaml

- name: Test data contract
  run: datacontract test datacontract.yaml --server staging

- name: Check for breaking changes
  run: |
    datacontract diff \
      <(git show main:datacontract.yaml) \
      datacontract.yaml \
      --fail-on breaking
```

## See Also

- [ODCS Specification](odcs-specification.md)
- [Testing and CI/CD](testing-and-cicd.md)
- [Pipeline Enforcement](pipeline-enforcement.md)
