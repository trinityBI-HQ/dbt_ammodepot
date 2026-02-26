# Data Engineering Knowledge Base

> **Last Updated:** 2026-02-19
> **Maintained By:** Claude Code Lab Team

## Overview

Data Engineering focuses on building reliable, scalable systems that collect, transform, and serve data for analytics, ML, and operational use cases. This category covers the full spectrum of the modern data stack.

## Philosophy

**Build data systems that are:**
- **Reliable**: Test-driven, monitored, with data quality checks
- **Scalable**: Handle growth without architectural rewrites
- **Observable**: Track lineage, performance, and data quality
- **Maintainable**: Self-documenting, version-controlled, modular

**Avoid:**
- ❌ Ad-hoc scripts without observability
- ❌ Untested data transformations
- ❌ Tightly coupled pipeline components
- ❌ Manual data quality checks

## Categories

### 🎯 Orchestration

**Technologies:** [Dagster](orchestration/dagster/)

**What it does:** Coordinate dependencies between data assets, schedule runs, manage execution.

**When to use:**
- Complex DAGs with cross-team dependencies
- Need for asset-based lineage and cataloging
- Integration with dbt, Spark, Pandas, etc.
- Development-to-production workflow automation

**Key capabilities:**
- Software-defined assets (declarative dependencies)
- Asset materialization and metadata
- Partitioned and incremental processing
- Testing and local development

**Alternatives:** Airflow (task-centric), Prefect (dataflow-centric), Temporal (workflow engine)

### 🔄 Transformation

**Technologies:** [dbt Core](transformation/dbt-core/), [dbt Cloud](transformation/dbt-cloud/)

**What it does:** Transform raw data into analytics-ready models using SQL and Jinja.

**When to use:**
- SQL-based transformations (vs Python)
- Need for testing and documentation at scale
- Medallion architecture (Bronze → Silver → Gold)
- Analytics engineering workflows

**Key capabilities:**
- Modular SQL with Jinja templating
- Built-in testing framework
- Automatic DAG generation from refs
- Git-based development workflow

**Core vs Cloud:**
- **dbt Core**: CLI-based, self-hosted, open source
- **dbt Cloud**: Managed CI/CD, scheduling, web IDE, enhanced observability

### 💾 Data Platforms

**Technologies:** [Snowflake](data-platforms/snowflake/)

**What it does:** Cloud data warehousing with separation of storage and compute.

**When to use:**
- Analytics workloads with variable compute needs
- Semi-structured data (JSON, Parquet, Avro)
- Need for instant scaling without infrastructure management
- Multi-cloud or hybrid cloud requirements

**Key capabilities:**
- Automatic clustering and optimization
- Time travel and zero-copy cloning
- Native VARIANT type for JSON
- Snowpipe for continuous ingestion

**Alternatives:** BigQuery (GCP-native), Redshift (AWS-native), Databricks (Lakehouse)

### 📐 Modeling

**Technologies:** [Data Vault 2.0](modeling/data-vault/)

**What it does:** Enterprise data warehouse modeling methodology using Hubs, Links, and Satellites for auditable, scalable integration layers.

**When to use:**
- Multiple source systems feeding a single warehouse
- Full audit trail and regulatory compliance required
- Agile/iterative development of the data warehouse
- Historical tracking of all changes (insert-only)

**Key capabilities:**
- Hub/Link/Satellite architecture (business keys, relationships, context)
- Hash-based keys for parallel loading
- Raw Vault (system of record) + Business Vault (derived)
- Integration with dbt via AutomateDV and DataVault4dbt

**Alternatives:** Star Schema (presentation-focused), 3NF (application databases), One Big Table (simple analytics)

**Common pattern:** Data Vault as integration layer + Star Schema marts as presentation layer.

### 🔍 Code Quality

**Technologies:** [Flake8](code-quality/flake8/)

**What it does:** Lint Python code for style violations (PEP 8), logical errors, and complexity issues.

**When to use:**
- Enforcing coding standards across data engineering teams
- Catching bugs early in dbt Python models, Dagster assets, or ETL scripts
- Pre-commit hooks and CI/CD quality gates
- Measuring cyclomatic complexity of pipeline functions

**Key capabilities:**
- Wraps pycodestyle (E/W), pyflakes (F), and mccabe (C) into one tool
- 200+ plugins for security (bandit), imports, docstrings, and more
- Per-file and per-line suppression with `noqa` and `per-file-ignores`
- Pre-commit and CI/CD integration

**Alternatives:** Ruff (Rust-based, 100x faster, replaces flake8+black+isort), Pylint (deeper analysis, slower), mypy (type checking only)

### 🔌 ELT

**Technologies:** [Airbyte](elt/airbyte/)

**What it does:** Extract data from sources and load into destinations (ELT not ETL).

**When to use:**
- Connecting to SaaS APIs (Salesforce, Stripe, Hubspot, etc.)
- Database replication (MySQL → Snowflake)
- Need for a large connector ecosystem
- Open-source alternative to Fivetran

**Key capabilities:**
- 300+ pre-built connectors
- CDC (Change Data Capture) support
- Custom connector development (Python)
- Normalization and dbt integration

**Alternatives:** Fivetran (managed, closed-source), Meltano (Singer-based, open source)

### 💰 FinOps

**Technologies:** [FinOps](finops/finops/)

**What it does:** Cloud financial operations framework for managing and optimizing data infrastructure costs across compute, storage, and warehouses.

**When to use:**
- Cloud spend on data infrastructure exceeds budget targets
- Teams lack visibility into per-pipeline or per-query costs
- Need to optimize Spark/Databricks clusters, Snowflake warehouses, or BigQuery slots
- Building cost governance and accountability for growing data platforms

**Key capabilities:**
- FinOps Framework lifecycle: Inform, Optimize, Operate
- Cost allocation via tagging, showback, and chargeback
- Unit economics (cost/query, cost/pipeline run, cost/GB processed)
- Cloud-specific optimization (AWS Savings Plans, GCP CUDs, Snowflake credits)
- Storage lifecycle management and data tiering
- Budget forecasting, anomaly detection, and governance policies

**Alternatives:** Ad-hoc cost monitoring (insufficient at scale), vendor-specific tools only (lacks cross-platform view)

### 📜 Data Governance

**Technologies:** [Data Contracts](data-governance/data-contracts/), [OpenMetadata](data-governance/openmetadata/)

**What it does:** Formal agreements between data producers and consumers, plus centralized metadata management, data discovery, lineage tracking, and governance.

**When to use:**
- Multiple teams produce and consume shared datasets
- Breaking schema changes cause downstream pipeline failures
- Transitioning to data mesh or domain-oriented architecture
- Need automated contract testing in CI/CD pipelines
- Regulatory compliance requires documented data quality standards

**Key capabilities:**
- Schema definitions with field types, constraints, and semantics
- Service-level agreements (freshness, availability, latency)
- Versioning with breaking change detection (semantic versioning)
- Tooling: datacontract-cli, ODCS standard, Soda, Confluent Schema Registry
- Integration with dbt model contracts, Dagster asset checks, Spark schema enforcement
- OpenMetadata: Data catalog with 80+ connectors, automated lineage, data quality profiler, RBAC governance

**Alternatives:** Ad-hoc schema documentation (insufficient), data catalogs alone (no enforcement), manual review processes (don't scale)

### 🧪 Data Quality

**Technologies:** [Great Expectations](data-quality/great-expectations/), [Soda](data-quality/soda/)

**What it does:** Validate data quality through declarative checks, profiling, and monitoring to catch issues before they reach consumers.

**When to use:**
- Pipeline quality gates (block bad data from production)
- Freshness, completeness, and uniqueness validation
- Schema stability monitoring after source changes
- CI/CD integration for data quality testing
- Data contracts enforcement between teams

**Key capabilities:**
- **Great Expectations**: Python API, 47+ built-in expectations, auto-generated Data Docs, multi-backend (Pandas, Spark, SQL)
- **Soda**: YAML-based SodaCL language, Soda Cloud for monitoring/anomaly detection, GitHub Action, data contracts support

**When to choose which:**
- **Soda**: YAML-first declarative checks, built-in SaaS monitoring, data contracts, lower learning curve
- **Great Expectations**: Programmatic Python API, custom expectations, statistical profiling, deeper customization

**Alternatives:** dbt tests (lightweight, SQL-only), Monte Carlo (observability SaaS), Elementary (dbt-native)

## Decision Frameworks

### Orchestration: When to Use What?

| Scenario | Recommended Tool | Why |
|----------|------------------|-----|
| Asset-based lineage | **Dagster** | First-class support for assets and metadata |
| Simple cron schedules | **dbt Cloud** | Built-in scheduling for transformations |
| Legacy task-based DAGs | **Airflow** | Industry standard for task orchestration |
| Event-driven workflows | **Dagster + Sensors** | React to S3, Snowflake, custom events |

### Modeling: Data Vault vs Star Schema vs 3NF?

| Scenario | Recommended | Why |
|----------|-------------|-----|
| Multi-source integration layer | **Data Vault** | Handles source changes without refactoring |
| BI/reporting presentation | **Star Schema** | Optimized for query performance |
| Single-source simple analytics | **Star Schema** | Data Vault is overkill |
| Audit trail / compliance | **Data Vault** | Insert-only, full history |
| Agile DW development | **Data Vault** | Additive changes, no refactoring |
| Combined approach | **Data Vault + Star Schema marts** | Best of both worlds |

### Transformation: SQL vs Python?

| Use Case | Recommended | Why |
|----------|-------------|-----|
| Analytics models | **dbt (SQL)** | SQL is standard for analytics, easier collaboration |
| Feature engineering | **Python (Pandas/Spark)** | Complex logic, ML preprocessing |
| Data quality rules | **dbt tests + macros** | Declarative, version-controlled, reusable |
| Real-time streaming | **Spark Structured Streaming** | Low-latency, stateful processing |

### Platform Selection: Snowflake vs Databricks vs BigQuery?

| Factor | Snowflake | Databricks | BigQuery |
|--------|-----------|------------|----------|
| **Best For** | Analytics, BI | Lakehouse, ML/AI | GCP-native, ad-hoc |
| **Storage** | Cloud storage (S3/GCS/Azure) | Delta Lake | BigQuery Storage |
| **Compute** | Virtual warehouses | Clusters + SQL warehouses | Serverless + reserved |
| **Data Science** | Python UDFs, Snowpark | Native (notebooks, MLflow) | Vertex AI integration |
| **Pricing** | Compute + storage separate | DBUs + cloud costs | On-demand or flat-rate |
| **Multi-cloud** | ✅ Yes | ✅ Yes | ❌ GCP only |

## Common Patterns

### Medallion Architecture

**Bronze → Silver → Gold** (or Raw → Refined → Aggregated)

```
Airbyte → Snowflake (Bronze) → dbt (Silver) → dbt (Gold) → BI Tools
         ↓                      ↓               ↓
      Raw data          Cleaned, joined    Business metrics
```

**Best practices:**
- Bronze: Raw ingestion, minimal transformation
- Silver: Cleaned, typed, joined, deduplicated
- Gold: Business-level aggregations and metrics

### Incremental Processing

**Problem:** Reprocessing all data is slow and expensive.

**Solutions:**
- **dbt incremental models** with `is_incremental()` macro
- **Dagster partitions** for date-based processing
- **Snowflake Streams** for CDC tracking

### Data Quality at Scale

**Layers of quality:**
1. **Schema validation** (Airbyte, Fivetran) - ensure columns exist
2. **dbt tests** (not_null, unique, relationships) - validate data integrity
3. **Soda** (SodaCL checks) - declarative quality gates, freshness, contracts
4. **Great Expectations** (advanced profiling) - statistical validation
5. **Dagster asset checks** (freshness, row counts) - operational monitoring

## Integration Patterns

### Dagster + dbt

```python
from dagster_dbt import dbt_cli_resource, load_assets_from_dbt_project

dbt_assets = load_assets_from_dbt_project(project_dir="path/to/dbt")
```

**Why:** Asset-based lineage across orchestration and transformation.

### dbt + Snowflake

```yaml
# profiles.yml
my_project:
  target: prod
  outputs:
    prod:
      type: snowflake
      account: my_account
      warehouse: transforming
      database: analytics
      schema: dbt_prod
```

**Why:** Snowflake's query pushdown optimizes dbt transformations.

### Airbyte + Dagster

Use Dagster sensors to trigger downstream assets when Airbyte sync completes.

## Best Practices

### General
✅ Version control all code (SQL, Python, configs)
✅ Test transformations before production
✅ Monitor data freshness and quality
✅ Document data models and lineage
✅ Use incremental processing where possible

### Orchestration
✅ Prefer assets over ops for most use cases
✅ Use partitions for time-series data
✅ Configure retries and alerts
✅ Separate dev/staging/prod environments

### Transformation
✅ Use dbt for SQL transformations (not stored procs)
✅ Test every model (not_null, unique, etc.)
✅ Document models in schema.yml
✅ Keep models modular (single responsibility)

### Platform
✅ Right-size compute (don't over-provision)
✅ Monitor query performance and costs
✅ Use clustering for large tables
✅ Leverage caching and result reuse

## Anti-Patterns

❌ **Spaghetti dependencies**: Models depend on 10+ upstream tables → Break into intermediate models
❌ **Monster queries**: 500+ line SQL files → Refactor into CTEs or upstream models
❌ **No testing**: Transformations without tests → Add dbt tests
❌ **Manual deployments**: Copy-paste SQL to production → Use CI/CD with dbt Cloud or Dagster
❌ **Ignoring lineage**: Can't trace data back to source → Use asset-based orchestration

## Recommended Learning Path

1. **Foundations** (2-4 weeks)
   - SQL fundamentals (JOINs, window functions, CTEs)
   - Data modeling concepts (star schema, normalization)
   - Git and version control basics

2. **Transformation** (2-3 weeks)
   - dbt Core fundamentals
   - Writing and testing models
   - Jinja templating and macros

3. **Orchestration** (2-3 weeks)
   - Dagster concepts (assets, jobs, resources)
   - Building and testing data pipelines
   - Scheduling and monitoring

4. **Platform** (1-2 weeks)
   - Snowflake architecture
   - Query optimization
   - Cost management

5. **Integration** (1-2 weeks)
   - ELT with Airbyte
   - End-to-end pipelines
   - Production deployment

## Related Knowledge

- **Cloud Infrastructure**: See [cloud/](../cloud/) for GCP/AWS/Azure deployment patterns
- **AI/ML**: See [ai-ml/](../ai-ml/) for feature engineering and ML pipelines
- **DevOps**: See [devops-sre/](../devops-sre/) for CI/CD and infrastructure automation
- **Automation**: See [automation/](../automation/) for workflow orchestration with n8n

## Agents

Specialized agents for data engineering tasks:
- `/dagster-expert` - Dagster pipeline development
- `/dbt-expert` - dbt models, tests, and macros
- `/snowflake-expert` - Query optimization, Snowpipe, Snowpark

---

**Build pipelines that scale • Test everything • Observe always**
