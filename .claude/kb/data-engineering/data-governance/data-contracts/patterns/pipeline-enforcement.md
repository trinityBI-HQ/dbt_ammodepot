# Pipeline Enforcement

> **Purpose**: Enforcing data contracts in dbt, Dagster, Spark, Kafka, and Snowflake pipelines
> **MCP Validated**: 2026-02-19

## When to Use

- Integrating contract validation into existing data pipelines
- Need automated enforcement at pipeline boundaries (ingestion, transformation, serving)
- Building quality gates that block bad data from propagating downstream
- Working with dbt, Dagster, Spark, or Kafka and want contract-first development

## dbt Model Contracts

dbt v1.5+ supports native model contracts that enforce column names, types, and constraints.

```yaml
# models/schema.yml
models:
  - name: orders
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: varchar
        constraints:
          - type: not_null
          - type: primary_key
      - name: customer_id
        data_type: varchar
        constraints:
          - type: not_null
          - type: foreign_key
            expression: "ref('customers') (customer_id)"
      - name: total_amount
        data_type: number(38,2)
        constraints:
          - type: not_null
          - type: check
            expression: "total_amount >= 0"
      - name: status
        data_type: varchar
        constraints:
          - type: not_null
          - type: accepted_values
            values: ['pending', 'confirmed', 'shipped', 'delivered']
```

**What happens:** If the model's SQL output doesn't match the contract (wrong columns, types, or constraints), `dbt run` fails before writing data.

### dbt Tests as Contract Checks

```yaml
models:
  - name: orders
    tests:
      - dbt_utils.expression_is_true:
          expression: "total_amount >= 0"
      - dbt_utils.recency:
          datepart: hour
          field: created_at
          interval: 1  # SLA: data within 1 hour
    columns:
      - name: order_id
        tests:
          - not_null
          - unique
```

## Dagster Asset Checks

Dagster asset checks validate contracts at the asset level.

```python
import dagster as dg

@dg.asset
def orders(context) -> pd.DataFrame:
    """Produce orders dataset."""
    return load_orders()

@dg.asset_check(asset=orders)
def orders_contract(context, orders: pd.DataFrame):
    """Validate orders data contract."""
    # Schema check
    expected_cols = {"order_id", "customer_id", "total_amount", "status"}
    actual_cols = set(orders.columns)
    missing = expected_cols - actual_cols
    if missing:
        return dg.AssetCheckResult(
            passed=False,
            metadata={"missing_columns": str(missing)},
        )

    # Quality checks
    null_pct = orders["order_id"].isnull().mean()
    if null_pct > 0:
        return dg.AssetCheckResult(
            passed=False,
            metadata={"order_id_null_pct": float(null_pct)},
        )

    # Freshness SLA
    max_age = pd.Timestamp.now() - orders["created_at"].max()
    if max_age > pd.Timedelta(hours=1):
        return dg.AssetCheckResult(
            passed=False,
            metadata={"max_age_hours": max_age.total_seconds() / 3600},
        )

    return dg.AssetCheckResult(passed=True)
```

## Spark Schema Enforcement

```python
from pyspark.sql.types import StructType, StructField, StringType, DecimalType

# Define contract schema
orders_contract = StructType([
    StructField("order_id", StringType(), nullable=False),
    StructField("customer_id", StringType(), nullable=False),
    StructField("total_amount", DecimalType(38, 2), nullable=False),
    StructField("status", StringType(), nullable=False),
])

# Enforce on read
df = spark.read.schema(orders_contract).parquet("s3://bucket/orders/")

# Validate at runtime
def validate_contract(df, contract_schema):
    actual = set((f.name, f.dataType) for f in df.schema.fields)
    expected = set((f.name, f.dataType) for f in contract_schema.fields)
    missing = expected - actual
    if missing:
        raise ValueError(f"Contract violation: missing {missing}")

    # Check nullability
    for field in contract_schema.fields:
        if not field.nullable:
            null_count = df.filter(df[field.name].isNull()).count()
            if null_count > 0:
                raise ValueError(
                    f"Contract violation: {field.name} has {null_count} nulls"
                )
```

## Kafka / Confluent Schema Registry

Schema Registry enforces contracts at serialization. Producers must register schemas that pass compatibility checks. Data contract rules add CEL-based validation:

```json
{
  "ruleSet": {
    "domainRules": [{
      "name": "validateAmount",
      "kind": "CONDITION",
      "type": "CEL",
      "mode": "WRITE",
      "expr": "message.total_amount >= 0",
      "onFailure": "DLQ"
    }]
  }
}
```

## Soda Core (Programmatic)

```python
from soda.core.scan import Scan

scan = Scan()
scan.set_data_source_name("snowflake")
scan.add_configuration_yaml_file("soda_conf.yaml")
scan.add_sodacl_yaml_file("contracts/orders.yaml")
scan.execute()
if scan.has_check_fails():
    raise RuntimeError(f"Contract failed: {scan.get_checks_fail()}")
```

## Enforcement Strategy

| Layer | Tool | When |
|-------|------|------|
| **Ingestion** | Schema Registry, Spark schema | On data arrival |
| **Transformation** | dbt contracts, dbt tests | During build |
| **Quality gate** | Soda, Great Expectations | Post-transform |
| **Orchestration** | Dagster asset checks | Per-asset |
| **Serving** | View-level contracts | On consumption |

## See Also

- [Fundamentals](../concepts/fundamentals.md)
- [Testing and CI/CD](testing-and-cicd.md)
- [datacontract-cli](datacontract-cli.md)
