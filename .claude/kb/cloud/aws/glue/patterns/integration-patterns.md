# Integration Patterns

> **Purpose**: Connect Glue with AWS services for end-to-end data platforms
> **MCP Validated**: 2026-02-19

## When to Use

- Building data lake architectures with S3, Athena, and Redshift
- Orchestrating Glue jobs with Step Functions or EventBridge
- Implementing governance with Lake Formation

## S3 Data Lake Integration

```
S3 (Bronze)              Glue                    S3 (Silver/Gold)
-----------         ----------------         -------------------
raw/events/ ------> | Crawler      | ------> processed/events/
raw/orders/ ------> | Data Catalog | ------> processed/orders/
                    | ETL Jobs     | ------> curated/reports/
                    ----------------
                          |
                    Athena / Redshift
```

```python
# Bronze → Silver transformation
bronze = glue_ctx.create_dynamic_frame.from_catalog(
    database="raw_db", table_name="events",
    push_down_predicate="dt='2025-01-15'",
)

# Clean, deduplicate, enrich
df = bronze.toDF()
df = df.dropDuplicates(["event_id"])
df = df.filter(col("event_type").isNotNull())
df = df.withColumn("processed_at", current_timestamp())

# Write to Silver layer
glue_ctx.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(df, glue_ctx, "silver"),
    connection_type="s3",
    connection_options={
        "path": "s3://data-lake/silver/events/",
        "partitionKeys": ["year", "month", "day"],
    },
    format="glueparquet",
    format_options={"compression": "snappy"},
)
```

## Athena Integration

The Data Catalog is Athena's metadata store. Tables cataloged by Glue are immediately queryable:

```sql
-- Query Glue catalog tables directly in Athena
SELECT customer_id, SUM(amount) as total_spend
FROM prod_sales_silver.orders
WHERE year = '2025' AND month = '06'
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 100;
```

**Optimization tip:** Ensure Parquet format + partition pruning for fast Athena queries.

## Redshift Integration

```python
# Write from Glue directly to Redshift
glue_ctx.write_dynamic_frame.from_options(
    frame=dyf,
    connection_type="redshift",
    connection_options={
        "redshiftTmpDir": "s3://temp/redshift/",
        "useConnectionProperties": "true",
        "dbtable": "public.orders",
        "connectionName": "redshift-cluster",
        "preactions": "TRUNCATE TABLE public.orders_staging;",
        "postactions": (
            "BEGIN; DELETE FROM public.orders USING public.orders_staging "
            "WHERE orders.id = orders_staging.id; "
            "INSERT INTO public.orders SELECT * FROM public.orders_staging; "
            "DROP TABLE public.orders_staging; COMMIT;"
        ),
    },
)
```

## Step Functions Orchestration

```
Crawler (sync) → ETL Job (sync) → Data Quality → Choice → Success / Alert
```

Key Step Functions resource ARNs for Glue integration:

| Action | Resource ARN |
|--------|-------------|
| Start crawler | `arn:aws:states:::glue:startCrawler.sync` |
| Start job | `arn:aws:states:::glue:startJobRun.sync` |
| Data quality | `arn:aws:states:::glue:startDataQualityRulesetEvaluationRun.sync` |

Use `.sync` suffix for synchronous execution (Step Functions waits for completion).

## EventBridge Scheduling

```python
# Trigger Glue job on S3 upload via EventBridge
events = boto3.client("events")

events.put_rule(
    Name="new-data-trigger",
    EventPattern=json.dumps({
        "source": ["aws.s3"],
        "detail-type": ["Object Created"],
        "detail": {
            "bucket": {"name": ["data-lake-raw"]},
            "object": {"key": [{"prefix": "sales/orders/"}]},
        },
    }),
)

events.put_targets(
    Rule="new-data-trigger",
    Targets=[{
        "Id": "glue-etl",
        "Arn": "arn:aws:glue:us-east-1:123:job/sales-etl",
        "RoleArn": "arn:aws:iam::123:role/EventBridgeGlueRole",
    }],
)
```

## Lake Formation Governance

```python
lf = boto3.client("lakeformation")

# Register S3 location and grant column-level access
lf.register_resource(ResourceArn="arn:aws:s3:::data-lake-prod", RoleArn="arn:aws:iam::123:role/LFRole")
lf.grant_permissions(
    Principal={"DataLakePrincipal": {"DataLakePrincipalIdentifier": "arn:aws:iam::123:role/AnalystRole"}},
    Resource={"TableWithColumns": {
        "DatabaseName": "prod_sales_silver", "Name": "customers",
        "ColumnNames": ["customer_id", "name", "city"],
    }},
    Permissions=["SELECT"],
)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `redshiftTmpDir` | Required | S3 path for Redshift COPY staging |
| `preactions` | None | SQL to run before write |
| `postactions` | None | SQL to run after write |
| `catalogPartitionPredicate` | None | Partition filter for reads |

## See Also

- [ETL Patterns](../patterns/etl-patterns.md)
- [Connections](../concepts/connections.md)
