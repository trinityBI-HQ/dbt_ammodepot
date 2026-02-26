# FinOps Quick Reference

> Fast lookup tables. For detailed examples, see linked files.
> **MCP Validated**: 2026-02-19

## FinOps Framework 2025

```
SCOPES: Public Cloud | SaaS | GenAI | Data Center | Licensing
PHASES: INFORM (visibility) --> OPTIMIZE (efficiency) --> OPERATE (governance)
          Tag, allocate,          Right-size, commit,       Automate, alert,
          measure, forecast       tier, schedule             enforce, iterate
```

## Cost Optimization by Platform

| Platform | Scope | Top Lever | Savings Potential | KB Pattern |
|----------|-------|-----------|-------------------|------------|
| Databricks | SaaS | Jobs clusters + spot | 60-90% | `patterns/data-pipeline-optimization.md` |
| Snowflake | SaaS | Warehouse sizing + auto-suspend | 30-60% | `patterns/warehouse-cost-management.md` |
| BigQuery | Cloud | Partitioning + editions | 40-70% | `patterns/warehouse-cost-management.md` |
| AWS S3 | Cloud | Lifecycle policies | 60-80% | `patterns/storage-optimization.md` |
| Spark on EMR/Dataproc | Cloud | Spot/preemptible + autoscale | 50-80% | `patterns/data-pipeline-optimization.md` |
| OpenAI/Bedrock/Vertex | GenAI | Model selection + caching | 40-80% | See concepts/framework.md |

## Tagging Strategy (Minimum Required)

| Tag Key | Values (Examples) | Purpose |
|---------|-------------------|---------|
| `team` | `data-eng`, `analytics`, `ml` | Cost allocation by team |
| `project` | `etl-pipeline`, `feature-store` | Cost allocation by project |
| `environment` | `dev`, `staging`, `prod` | Separate non-prod waste |
| `pipeline` | `bronze-ingest`, `silver-transform` | Per-pipeline cost tracking |
| `owner` | `jane.doe@company.com` | Accountability contact |

## Unit Economics Formulas

| Metric | Formula | Target |
|--------|---------|--------|
| Cost per pipeline run | Total pipeline cost / run count | Track trend, not absolute |
| Cost per query | Warehouse cost / query count | < $0.10 for ad-hoc |
| Cost per GB processed | Compute cost / GB processed | Benchmark by workload type |
| Compute utilization | Active compute / provisioned | > 70% |
| Storage efficiency | Hot storage / total storage | < 30% (most data is cold) |

## Commitment Discount Types

| Provider | Mechanism | Discount | Commitment |
|----------|-----------|----------|------------|
| AWS | Savings Plans (Compute) | Up to 72% | 1 or 3 year |
| AWS | Reserved Instances | Up to 72% | 1 or 3 year |
| GCP | Committed Use Discounts | Up to 57% | 1 or 3 year |
| GCP | Sustained Use Discounts | Up to 30% | Automatic |
| Snowflake | Capacity contracts | 10-30%+ | Annual |
| Databricks | Committed spend | Negotiated | Annual |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Run all-purpose Databricks clusters for jobs | Use Jobs clusters (3-4x cheaper in DBUs) |
| Leave Snowflake warehouses on auto-resume only | Set auto-suspend to 60 seconds |
| Store all S3 data in Standard tier | Use lifecycle rules to tier to IA/Glacier |
| Skip tagging on dev/test resources | Tag everything; dev waste adds up fast |
| Buy commitments without usage analysis | Analyze 30-60 days of usage first |
| Ignore query patterns in BigQuery | Partition and cluster tables by common filters |

## Decision Matrix

| Situation | Action |
|-----------|--------|
| Predictable baseline compute | Buy Savings Plans / CUDs |
| Spiky, fault-tolerant workloads | Use spot / preemptible instances |
| Data accessed < 1x/month | Move to Infrequent Access tier |
| Data accessed < 1x/year | Move to Glacier / Archive |
| Snowflake queries < 5 min avg | Consider downsizing warehouse |
| BigQuery scanning > 1 TB/query | Add partitioning and clustering |

## Related Documentation

| Topic | Path |
|-------|------|
| FinOps Framework | `concepts/framework.md` |
| Cost Allocation | `concepts/cost-allocation.md` |
| Full Index | `index.md` |
