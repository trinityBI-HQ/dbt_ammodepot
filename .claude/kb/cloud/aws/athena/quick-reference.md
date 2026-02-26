# AWS Athena Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Pricing

| Engine | Cost | Unit |
|--------|------|------|
| Trino (SQL) | $5.00 | Per TB scanned |
| Spark (notebook) | $0.01725 | Per DPU-hour |
| Provisioned capacity | $0.227 | Per DPU-hour |

Cancelled queries are billed for data already scanned. Minimum 10 MB per query.

## Data Format Performance

| Format | Scan Cost | Query Speed | Splittable | Best For |
|--------|-----------|-------------|------------|----------|
| Parquet | Lowest | Fastest | Yes | Analytics (default choice) |
| ORC | Lowest | Fast | Yes | Hive ecosystem |
| JSON | Highest | Slow | Yes (newline) | Semi-structured logs |
| CSV | High | Slow | Yes | Simple exports |
| Avro | Medium | Medium | Yes | Schema evolution |

## Common SQL Patterns

| Task | SQL |
|------|-----|
| Create table from query | `CREATE TABLE new_t AS SELECT ...` |
| Create table (external) | `CREATE EXTERNAL TABLE t (...) STORED AS PARQUET LOCATION 's3://...'` |
| Add partition | `ALTER TABLE t ADD PARTITION (dt='2025-01-01') LOCATION 's3://...'` |
| Repair partitions | `MSCK REPAIR TABLE t` |
| Show create | `SHOW CREATE TABLE t` |
| Unload to S3 | `UNLOAD (SELECT ...) TO 's3://...' WITH (format='PARQUET')` |
| Explain query | `EXPLAIN SELECT ...` |

## Engine Versions

| Version | Engine | Key Features |
|---------|--------|--------------|
| v3 (current) | Trino | Best performance, Iceberg support, federated queries |
| Spark | Apache Spark 3.5 | Notebook analytics, SparkConnect, SageMaker integration |
| v2 | Presto 0.217 | Legacy, fewer features |

Always use **Athena v3** for SQL workgroups. Use **Spark** for notebook-based analytics.

## Recent Features (2025-2026)

| Feature | Date | Description |
|---------|------|-------------|
| Spark in SageMaker notebooks | Nov 2025 | Unified SQL/Python/Spark workspace |
| Materialized views (Athena SQL) | Nov 2025 | Query Glue Data Catalog materialized views |
| 1-minute Capacity Reservations | Feb 2026 | Finer capacity control, 4 DPU minimum |
| SparkConnect support | 2025 | Standard Spark connectivity for Spark engine |
| DPU usage tracking | 2025 | Track DPU consumption on Capacity Reservation queries |

## CLI Commands

| Command | Description |
|---------|-------------|
| `aws athena start-query-execution --query-string "SQL"` | Execute query |
| `aws athena get-query-execution --query-execution-id X` | Check status |
| `aws athena get-query-results --query-execution-id X` | Get results |
| `aws athena list-work-groups` | List workgroups |
| `aws athena create-work-group --name X` | Create workgroup |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Ad-hoc SQL on S3 data | Athena (serverless, no setup) |
| Heavy concurrent BI queries | Athena provisioned capacity |
| Complex ETL transformations | Glue ETL or Spark |
| Sub-second queries | Redshift / DynamoDB |
| ACID transactions on S3 | Athena + Iceberg tables |
| Cross-source joins | Athena federated queries |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Query JSON/CSV at scale | Convert to Parquet first (CTAS) |
| Scan full table every query | Partition + use WHERE on partition keys |
| Use `SELECT *` | Project only needed columns |
| Skip MSCK REPAIR after adding data | Use partition projection or `ALTER TABLE ADD PARTITION` |
| Ignore workgroup limits | Set per-query and per-workgroup scan limits |
| Use v2 engine | Upgrade to v3 (Trino) for better performance |
| Over-provision capacity | Use 1-min reservations with 4 DPU minimum |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/query-engine.md` |
| Full Index | `index.md` |
