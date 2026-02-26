# Catalog Management

> **Purpose**: Organize and govern the Glue Data Catalog at scale
> **MCP Validated**: 2026-02-19

## When to Use

- Managing hundreds of tables across multiple teams and domains
- Implementing data lake naming conventions and governance
- Sharing catalog resources across AWS accounts with Lake Formation

## Naming Conventions

```
Database:  {env}_{domain}_{layer}
           prod_sales_bronze
           dev_marketing_silver

Table:     {entity}_{version}
           orders_v2
           customers_v1

Partition: year=YYYY/month=MM/day=DD
           or: dt=YYYY-MM-DD
```

| Component | Convention | Example |
|-----------|-----------|---------|
| Database | `{env}_{domain}_{layer}` | `prod_sales_raw` |
| Table | `{entity}` or `{entity}_{version}` | `orders`, `orders_v2` |
| Partition | Hive-style keys | `year=2025/month=01` |
| Connection | `{env}_{source}_{type}` | `prod_rds_postgres_jdbc` |

## Medallion Architecture in Catalog

```python
import boto3

glue = boto3.client("glue")

# Create layered databases
for env in ["dev", "prod"]:
    for domain in ["sales", "marketing", "finance"]:
        for layer in ["bronze", "silver", "gold"]:
            glue.create_database(
                DatabaseInput={
                    "Name": f"{env}_{domain}_{layer}",
                    "Description": f"{layer.title()} layer for {domain} domain",
                    "LocationUri": f"s3://data-lake-{env}/{domain}/{layer}/",
                    "Parameters": {
                        "environment": env,
                        "domain": domain,
                        "layer": layer,
                        "owner": f"{domain}-team",
                    },
                }
            )
```

## Partition Strategy

### Time-Based Partitioning

```python
# Optimal for time-series data queried by date range
partition_keys = [
    {"Name": "year", "Type": "string"},
    {"Name": "month", "Type": "string"},
    {"Name": "day", "Type": "string"},
]
# Path: s3://lake/orders/year=2025/month=01/day=15/

# For high-volume data, add hour
partition_keys.append({"Name": "hour", "Type": "string"})
```

### Register Partitions Efficiently

```python
# Batch API: up to 100 partitions per call
partitions = []
for year in range(2024, 2026):
    for month in range(1, 13):
        partitions.append({
            "Values": [str(year), f"{month:02d}"],
            "StorageDescriptor": {
                "Location": f"s3://lake/orders/year={year}/month={month:02d}/",
                "InputFormat": "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat",
                "OutputFormat": "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat",
                "SerdeInfo": {
                    "SerializationLibrary": "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
                },
                "Columns": table_columns,  # Same as table schema
            },
        })

# Send in batches of 100
for i in range(0, len(partitions), 100):
    glue.batch_create_partition(
        DatabaseName="prod_sales_bronze",
        TableName="orders",
        PartitionInputList=partitions[i : i + 100],
    )
```

## Cross-Account Catalog Sharing

### With Lake Formation

```python
# Grant access to another account
lakeformation = boto3.client("lakeformation")

lakeformation.grant_permissions(
    Principal={"DataLakePrincipal": {"DataLakePrincipalIdentifier": "123456789012"}},
    Resource={
        "Table": {
            "DatabaseName": "prod_sales_silver",
            "Name": "orders",
            "CatalogId": "987654321098",
        }
    },
    Permissions=["SELECT", "DESCRIBE"],
)
```

### With Resource Links

```python
# Create resource link in consumer account to shared table
glue.create_table(
    DatabaseName="shared_sales",
    TableInput={
        "Name": "orders",
        "TargetTable": {
            "CatalogId": "987654321098",  # Producer account
            "DatabaseName": "prod_sales_silver",
            "Name": "orders",
        },
    },
)
```

## Table Versioning

The Catalog retains schema versions. Query historical schemas:

```python
# Get table version history
versions = glue.get_table_versions(
    DatabaseName="prod_sales_bronze",
    TableName="orders",
    MaxResults=10,
)

# Roll back to a previous version
glue.update_table(
    DatabaseName="prod_sales_bronze",
    TableInput=versions["TableVersions"][2]["Table"],  # Version 2
)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `TableGroupingPolicy` | `CombineCompatibleSchemas` | How crawlers group files |
| `SchemaChangePolicy` | `UPDATE_IN_DATABASE` | How schema changes are handled |
| `DeleteBehavior` | `DEPRECATE_IN_DATABASE` | How deleted objects are handled |

## See Also

- [Data Catalog](../concepts/data-catalog.md)
- [Crawlers](../concepts/crawlers.md)
