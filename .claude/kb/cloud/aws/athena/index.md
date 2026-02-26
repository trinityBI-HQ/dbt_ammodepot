# AWS Athena Knowledge Base

> **Purpose**: Serverless interactive SQL on S3 -- query data where it lives, pay per scan
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/query-engine.md](concepts/query-engine.md) | Trino engine, SQL dialect, engine versions |
| [concepts/workgroups.md](concepts/workgroups.md) | Workgroups, result locations, cost controls |
| [concepts/tables-views.md](concepts/tables-views.md) | External tables, views, CTAS, prepared statements |
| [concepts/data-formats.md](concepts/data-formats.md) | Parquet, ORC, JSON, CSV, Iceberg, Hudi, Delta |
| [concepts/partitions.md](concepts/partitions.md) | Partition projection, Hive-style, pruning strategies |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/query-optimization.md](patterns/query-optimization.md) | Columnar formats, predicate pushdown, CTAS |
| [patterns/cost-management.md](patterns/cost-management.md) | Scan limits, format optimization, workgroup budgets |
| [patterns/integration-patterns.md](patterns/integration-patterns.md) | Glue Catalog, QuickSight, Lambda, Step Functions |
| [patterns/iceberg-tables.md](patterns/iceberg-tables.md) | ACID transactions, time travel, schema evolution |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Serverless SQL** | No infrastructure; pay $5/TB scanned |
| **Trino Engine** | Athena v3 uses Trino (formerly PrestoSQL) |
| **Glue Catalog** | Shared metadata store for table definitions |
| **Workgroups** | Isolate queries, control costs, manage access |
| **Partition Projection** | Eliminate partition lookup for known patterns |
| **Apache Iceberg** | ACID tables with time travel on S3 |
| **Spark in SageMaker** | Unified SQL/Python/Spark workspace in notebooks (Nov 2025) |
| **Materialized Views** | Precomputed Glue Data Catalog views queryable via Athena SQL |
| **Capacity Reservations** | 1-minute reservations, 4 DPU minimum (Feb 2026) |

---

## Architecture

```
Clients                  Athena                     Data Sources
-------           ------------------           -----------------
Console   ------> | Trino Engine   | --------> S3 (primary)
JDBC/ODBC ------> | Workgroups     | --------> Glue Catalog
SDK/CLI   ------> | Query Results  | --------> JDBC (federated)
QuickSight -----> |   → S3 output  | --------> DynamoDB (federated)
                  ------------------           HBase, Redis, etc.
```

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/query-engine.md, concepts/tables-views.md |
| **Intermediate** | concepts/partitions.md, patterns/query-optimization.md |
| **Advanced** | patterns/iceberg-tables.md, patterns/cost-management.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ai-data-engineer | patterns/integration-patterns.md | Athena in data pipelines |
| spark-specialist | patterns/iceberg-tables.md | Spark + Iceberg on Athena |
| aws-lambda-architect | patterns/integration-patterns.md | Lambda querying Athena |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| AWS Glue | `../glue/` | Data Catalog, crawlers, ETL into Athena |
| AWS S3 | `../s3/` | Underlying storage for all Athena tables |
| Terraform | `../../../devops-sre/iac/terraform/` | IaC for Athena workgroups |
| Snowflake | `../../../data-engineering/data-platforms/snowflake/` | Alternative managed warehouse |
| dbt | `../../../data-engineering/transformation/dbt/` | SQL transformations via Athena adapter |
