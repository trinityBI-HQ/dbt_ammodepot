# AWS Glue Knowledge Base

> **Purpose**: Serverless data integration -- ETL, Data Catalog, crawlers, and data quality at scale
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/data-catalog.md](concepts/data-catalog.md) | Databases, tables, schemas, Hive metastore compatibility |
| [concepts/etl-jobs.md](concepts/etl-jobs.md) | Job types, worker types, DPUs, bookmarks, Spark runtime |
| [concepts/crawlers.md](concepts/crawlers.md) | Schema discovery, classifiers, partition detection |
| [concepts/connections.md](concepts/connections.md) | JDBC, S3, Kafka, VPC networking, security configs |
| [concepts/glue-studio.md](concepts/glue-studio.md) | Visual ETL editor, DAG builder, job monitoring |
| [concepts/data-quality.md](concepts/data-quality.md) | DQDL rules, recommendations, quality scoring |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/etl-patterns.md](patterns/etl-patterns.md) | Incremental loads, bookmarks, error handling, schema evolution |
| [patterns/catalog-management.md](patterns/catalog-management.md) | Naming conventions, partitioning, cross-account sharing |
| [patterns/performance-optimization.md](patterns/performance-optimization.md) | Worker sizing, pushdown predicates, partition pruning |
| [patterns/integration-patterns.md](patterns/integration-patterns.md) | S3, Athena, Redshift, Lake Formation, Step Functions |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Data Catalog** | Centralized metadata repository, Hive metastore compatible |
| **ETL Jobs** | Serverless Spark-based jobs with auto-scaling workers |
| **Crawlers** | Automatic schema discovery and partition detection |
| **DynamicFrame** | Glue's extension of Spark DataFrame with schema flexibility |
| **Job Bookmarks** | State tracking for incremental ETL processing |
| **DQDL** | Data Quality Definition Language for rule-based validation |
| **Glue 5.0/5.1** | Latest versions: Spark 3.5.6, Python 3.11, Iceberg 1.10.0 |
| **Data Catalog Views** | Virtual tables queryable across engines (Glue 5.0+) |
| **Materialized Views** | Iceberg-backed precomputed views (Glue 5.1+) |

---

## Architecture

```
Data Sources          AWS Glue                    Consumers
-----------    ----------------------    ---------------------
S3 (files) --> | Crawlers           | --> Athena (SQL queries)
RDS/JDBC   --> |   ↓                | --> Redshift (warehouse)
Kafka      --> | Data Catalog       | --> EMR (processing)
DynamoDB   --> |   ↓                | --> SageMaker (ML)
             | ETL Jobs (Spark)   | --> S3 (data lake)
             | Data Quality       | --> Lake Formation
             ----------------------
```

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/data-catalog.md, concepts/crawlers.md |
| **Intermediate** | concepts/etl-jobs.md, patterns/etl-patterns.md |
| **Advanced** | patterns/performance-optimization.md, patterns/integration-patterns.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| lambda-builder | patterns/integration-patterns.md | Glue job triggers from Lambda |
| aws-lambda-architect | concepts/connections.md | IAM for Glue access |
| spark-specialist | patterns/performance-optimization.md | Spark tuning in Glue |
| ai-data-engineer | patterns/etl-patterns.md | Pipeline design with Glue |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| AWS S3 | `../s3/` | Primary data lake storage for Glue |
| Terraform | `../../../devops-sre/iac/terraform/` | IaC for Glue resources |
| Dagster | `../../../data-engineering/orchestration/dagster/` | Orchestrate Glue jobs |
| dbt | `../../../data-engineering/transformation/dbt/` | Transform data cataloged by Glue |
| Snowflake | `../../../data-engineering/data-platforms/snowflake/` | Alternative to Athena/Redshift |
