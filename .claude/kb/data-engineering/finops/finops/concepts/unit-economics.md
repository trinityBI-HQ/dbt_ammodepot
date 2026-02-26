# Unit Economics

> **Purpose**: Measuring data engineering cost efficiency through business-aligned metrics
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Unit economics bridges the gap between cloud spend and business value. Instead of reporting "we spent $50K on Snowflake," unit economics says "each customer report costs $0.12 to generate." This reframes cloud cost as a business metric, enabling engineering teams to optimize what matters and finance teams to understand why spending changes.

## Core Metrics for Data Engineering

### Compute Metrics

| Metric | Formula | Why It Matters |
|--------|---------|----------------|
| Cost per pipeline run | Pipeline compute cost / run count | Tracks pipeline efficiency over time |
| Cost per dbt model | Warehouse cost during run / model count | Identifies expensive models |
| Cost per Spark job | Cluster cost / job count | Compares job efficiency |
| Compute utilization | Active compute time / provisioned time | Measures waste (target: >70%) |
| Cost per DAG execution | Total orchestrator cost / DAG runs | Tracks orchestration overhead |

### Query Metrics

| Metric | Formula | Why It Matters |
|--------|---------|----------------|
| Cost per query | Warehouse credits / query count | Identifies expensive patterns |
| Cost per TB scanned | Query cost / data scanned (TB) | Measures scan efficiency |
| Query cost by user/team | Warehouse cost attributed to user | Enables chargeback |
| Cost per BI dashboard refresh | Refresh compute cost / dashboard count | Ties cost to consumer value |

### Storage Metrics

| Metric | Formula | Why It Matters |
|--------|---------|----------------|
| Cost per GB stored | Storage spend / total volume | Tracks storage unit cost |
| Hot/cold ratio | Hot storage GB / total GB | Target: <30% hot |
| Cost per table | Storage + compute for table / table count | Identifies expensive tables |
| Storage growth rate | Month-over-month GB increase | Predicts future costs |

### Business-Aligned Metrics

| Metric | Formula | Example |
|--------|---------|---------|
| Cost per customer report | Pipeline + query cost / reports generated | $0.12/report |
| Cost per data product | Full pipeline cost / product count | $500/month per product |
| Cost per ML prediction | Inference + data prep cost / predictions | $0.002/prediction |
| Revenue per dollar of data spend | Revenue attributed / data infra cost | $5 revenue per $1 spent |

## Implementation Pattern

### Step 1: Instrument Your Pipelines

```python
# Dagster: Track cost metadata per asset materialization
@asset(metadata={"cost_center": "analytics"})
def customer_summary(context, raw_customers):
    start_time = time.time()
    result = transform(raw_customers)
    duration = time.time() - start_time

    context.add_output_metadata({
        "rows_processed": len(result),
        "processing_seconds": duration,
        "estimated_cost_usd": duration * COST_PER_SECOND,
    })
    return result
```

### Step 2: Query Platform Cost Data

```sql
-- Snowflake: Cost per query (last 30 days)
SELECT
    user_name,
    query_type,
    COUNT(*) AS query_count,
    SUM(credits_used_cloud_services) AS total_credits,
    AVG(credits_used_cloud_services) AS avg_credits_per_query,
    SUM(bytes_scanned) / POWER(1024, 4) AS tb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY user_name, query_type
ORDER BY total_credits DESC;
```

### Step 3: Build Unit Cost Dashboard

```
Key dashboard panels:
1. Cost per pipeline run (trend over 30/60/90 days)
2. Cost per query by team (bar chart)
3. Storage cost by tier (stacked area)
4. Compute utilization rate (gauge, target >70%)
5. Top 10 most expensive pipelines (table)
6. Cost anomalies (highlight >2 std deviations)
```

## Setting Targets

| Metric | Crawl Target | Walk Target | Run Target |
|--------|-------------|-------------|------------|
| Compute utilization | >50% | >70% | >85% |
| Tagged resources | >80% | >95% | >99% |
| Hot storage ratio | <50% | <30% | <15% |
| Cost forecast accuracy | +/- 30% | +/- 15% | +/- 5% |

## Common Mistakes

### Wrong

```text
- Report only total cloud spend ("we spent $100K this month")
- Measure cost without context ("Snowflake costs went up 20%")
- Optimize for lowest cost (sacrificing SLAs or data quality)
```

### Correct

```text
- Report unit costs ("cost per pipeline run dropped from $2.40 to $1.80")
- Contextualize changes ("credits up 20% because data volume grew 35%")
- Optimize for cost efficiency ("same output at 25% less cost")
```

## Related

- [Cost Allocation](cost-allocation.md) -- Tags enable unit economics attribution
- [Framework](framework.md) -- Unit economics is a key Inform capability
- [Budgets and Forecasting](budgets-forecasting.md) -- Unit costs improve forecast accuracy
