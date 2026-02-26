# Integration Patterns

> **Purpose**: Connect Athena with AWS services for end-to-end analytics
> **MCP Validated**: 2026-02-19

## When to Use

- Building analytics pipelines with Glue, S3, and QuickSight
- Automating Athena queries with Lambda or Step Functions
- Querying across multiple data sources with federation

## Glue Catalog Integration

Athena uses the Glue Data Catalog as its metadata store. Tables created by crawlers or Glue ETL are instantly queryable:

```
Glue Crawler → Data Catalog → Athena SQL
     ↓              ↓              ↓
  S3 data    Tables/Partitions  Query results → S3
```

```sql
-- Tables from Glue Catalog are ready to query
SELECT * FROM glue_db.orders WHERE year = '2025' LIMIT 10;

-- Glue crawlers keep schemas current
-- Partition projection eliminates MSCK REPAIR
```

## Lambda Integration

### Query Athena from Lambda

```python
import boto3
import time

def lambda_handler(event, context):
    athena = boto3.client("athena")

    response = athena.start_query_execution(
        QueryString=f"""
            SELECT customer_id, SUM(amount) AS total
            FROM sales_db.orders
            WHERE dt = '{event["date"]}'
            GROUP BY customer_id
        """,
        WorkGroup="lambda-queries",
        QueryExecutionContext={"Database": "sales_db"},
    )

    query_id = response["QueryExecutionId"]

    # Poll for completion
    while True:
        status = athena.get_query_execution(QueryExecutionId=query_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)

    if state == "SUCCEEDED":
        results = athena.get_query_results(QueryExecutionId=query_id)
        return {"rows": len(results["ResultSet"]["Rows"]) - 1}
    else:
        raise Exception(f"Query {state}: {status['QueryExecution']['Status']}")
```

## Step Functions Orchestration

```json
{
  "StartAt": "RunQuery",
  "States": {
    "RunQuery": {
      "Type": "Task",
      "Resource": "arn:aws:states:::athena:startQueryExecution.sync",
      "Parameters": {
        "QueryString": "SELECT COUNT(*) FROM sales_db.orders WHERE dt='2025-06-15'",
        "WorkGroup": "etl-pipeline",
        "QueryExecutionContext": {"Database": "sales_db"}
      },
      "Next": "GetResults"
    },
    "GetResults": {
      "Type": "Task",
      "Resource": "arn:aws:states:::athena:getQueryResults",
      "Parameters": {
        "QueryExecutionId.$": "$.QueryExecution.QueryExecutionId"
      },
      "End": true
    }
  }
}
```

The `.sync` suffix makes Step Functions wait for query completion.

## QuickSight Dashboards

```
Athena (data source) → QuickSight SPICE dataset → Dashboard
```

- QuickSight connects directly to Athena workgroups
- SPICE datasets cache results in memory for fast dashboards
- Schedule SPICE refreshes to avoid repeated Athena scans

## Federated Queries

Query external sources alongside S3 data:

```sql
-- Join S3 data with RDS via Lambda connector
SELECT s3_orders.order_id, rds_customers.name, s3_orders.amount
FROM awsdatacatalog.sales_db.orders AS s3_orders
JOIN rds_connector.public.customers AS rds_customers
    ON s3_orders.customer_id = rds_customers.id
WHERE s3_orders.dt = '2025-06-15';
```

**Available connectors:**

| Connector | Data Source |
|-----------|------------|
| `rds` | RDS MySQL, PostgreSQL |
| `redshift` | Amazon Redshift |
| `dynamodb` | DynamoDB tables |
| `opensearch` | OpenSearch domains |
| `cloudwatch` | CloudWatch Logs |
| `cmdb` | AWS Config/resource inventory |

## EventBridge Scheduled Queries

```python
# Schedule daily aggregation via EventBridge → Lambda → Athena
events = boto3.client("events")

events.put_rule(
    Name="daily-aggregation",
    ScheduleExpression="cron(0 6 * * ? *)",  # 6 AM UTC daily
)

events.put_targets(
    Rule="daily-aggregation",
    Targets=[{
        "Id": "athena-aggregation",
        "Arn": "arn:aws:lambda:us-east-1:123:function:run-athena-query",
        "Input": '{"date": "today"}',
    }],
)
```

## S3 Output Management

```python
# Clean up old query results
s3 = boto3.client("s3")

# Set lifecycle rule on results bucket
s3.put_bucket_lifecycle_configuration(
    Bucket="athena-results",
    LifecycleConfiguration={
        "Rules": [{
            "ID": "expire-old-results",
            "Status": "Enabled",
            "Filter": {"Prefix": ""},
            "Expiration": {"Days": 7},
        }]
    },
)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Query timeout | 30 min | Max execution time |
| Concurrent DML queries | 25 | Per account limit |
| Concurrent DDL queries | 20 | Per account limit |
| SPICE refresh | Manual | Schedule in QuickSight |

## See Also

- [Query Engine](../concepts/query-engine.md)
- [Workgroups](../concepts/workgroups.md)
