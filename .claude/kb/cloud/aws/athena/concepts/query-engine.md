# Query Engine

> **Purpose**: Trino-based serverless SQL engine for S3 analytics
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Athena v3 runs on Trino (formerly PrestoSQL), a distributed SQL engine optimized for interactive analytics. It processes queries by scanning data directly in S3 without loading it into a database. Athena also supports Apache Spark for notebook-based analytics, including integration with SageMaker notebooks (Nov 2025) and SparkConnect support.

## Engine Versions

| Version | Engine | Status | Key Differences |
|---------|--------|--------|----------------|
| v3 | Trino | Current | Best performance, Iceberg/Hudi/Delta, federated queries |
| v2 | Presto 0.217 | Legacy | Limited features, no Iceberg |

Upgrade via workgroup settings. No data migration required.

## Spark Engine

Athena for Apache Spark provides notebook-based analytics with SageMaker integration (Nov 2025), SparkConnect support, and Spark 3.5.6 at $0.01725/DPU-hour. New APIs: `GetSessionEndpoint`, `GetResourceDashboard`.

## SQL Dialect

Athena v3 supports ANSI SQL with Trino extensions:

```sql
-- Window functions
SELECT customer_id, order_date, amount,
    SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date) AS running_total
FROM orders;

-- CTEs
WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', order_date) AS month, SUM(amount) AS total
    FROM orders
    GROUP BY 1
)
SELECT month, total, LAG(total) OVER (ORDER BY month) AS prev_month
FROM monthly_sales;

-- UNNEST for arrays/maps
SELECT id, tag
FROM events
CROSS JOIN UNNEST(tags) AS t(tag);

-- TRY for safe casting
SELECT TRY(CAST(price_str AS DOUBLE)) AS price FROM raw_data;
```

## Federated Queries

Query external data sources through Lambda-based connectors:

```sql
-- Query RDS via federated connector
SELECT c.name, o.total
FROM awsdatacatalog.sales_db.orders o
JOIN lambda_rds.public.customers c ON o.customer_id = c.id
WHERE o.year = '2025';
```

**Available connectors:** RDS/Aurora, Redshift, DynamoDB, OpenSearch, CloudWatch Logs, Redis, HBase, CMDB, DocumentDB, Neptune, Timestream, and custom via SDK.

## Query Execution Flow

```
1. SQL submitted → Athena query planner
2. Planner reads table metadata from Glue Catalog
3. Partition pruning applied (predicate pushdown)
4. Trino workers scan S3 objects in parallel
5. Results aggregated and written to S3 output location
6. Client reads results from S3
```

## Prepared Statements

```sql
-- Create parameterized query
PREPARE my_query FROM
SELECT * FROM orders WHERE customer_id = ? AND year = ?;

-- Execute with parameters
EXECUTE my_query USING 'cust-123', '2025';
```

Prevents SQL injection and enables query plan caching.

## Query Limits

| Limit | Value |
|-------|-------|
| Query string length | 256 KB |
| Query result size | Unlimited (written to S3) |
| Concurrent queries (default) | 25 DML, 20 DDL per account |
| Query timeout | 30 minutes (default) |
| Databases per catalog | 10,000 |
| Tables per database | 3,000,000 |

## The Pattern

```python
import boto3

athena = boto3.client("athena")

response = athena.start_query_execution(
    QueryString="SELECT COUNT(*) FROM sales_db.orders WHERE year='2025'",
    QueryExecutionContext={"Database": "sales_db", "Catalog": "awsdatacatalog"},
    WorkGroup="analytics-team",
)

query_id = response["QueryExecutionId"]

# Poll for completion
waiter = athena.get_waiter("query_succeeded")  # Athena v3+
waiter.wait(QueryExecutionId=query_id)

# Get results
results = athena.get_query_results(QueryExecutionId=query_id)
for row in results["ResultSet"]["Rows"][1:]:  # Skip header
    print([col.get("VarCharValue", "") for col in row["Data"]])
```

## Common Mistakes

### Wrong

```sql
-- No partition filter = full table scan ($$$)
SELECT * FROM events WHERE event_type = 'click';
```

### Correct

```sql
-- Include partition key in WHERE clause
SELECT * FROM events WHERE year='2025' AND month='01' AND event_type = 'click';
```

## Related

- [Workgroups](../concepts/workgroups.md)
- [Query Optimization](../patterns/query-optimization.md)
