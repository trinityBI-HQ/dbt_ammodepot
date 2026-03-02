# LakeView Observability

> **Purpose**: Free lakehouse monitoring tool providing metrics, alerts, and optimization insights via metadata analysis
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

LakeView is Onehouse's free observability tool for monitoring Apache Hudi data lakehouse tables. It analyzes table metadata only -- no Parquet/data files are accessed and no business data leaves the customer's cloud. LakeView provides interactive charts, pre-built dashboards, configurable alerts, and weekly health summaries. It helps teams identify data skew, compaction backlogs, clustering delays, and other optimization opportunities without requiring any compute infrastructure.

## The Pattern

```text
LakeView Architecture
=====================

Customer Data Plane              Onehouse Control Plane
+-------------------+           +----------------------+
| Hudi Tables       |           | LakeView Dashboard   |
| .hoodie/          |  push     |                      |
|   timeline/       |  metadata | - Table metrics      |
|   metadata/       |---------->| - File size charts   |
|                   |           | - Partition analysis  |
| (Parquet files    |           | - Compaction backlog  |
|  NEVER accessed)  |           | - Data skew alerts   |
+-------------------+           | - Weekly summaries   |
                                +----------------------+
                                     |          |
                                     v          v
                                  Email     Slack
                                  Alerts    Alerts
```

## Quick Reference

| Feature | Description |
|---------|-------------|
| **Table Metrics** | Write throughput, commit frequency, file counts, sizes |
| **Partition Analysis** | Data distribution, skew detection across partitions |
| **Compaction Backlog** | Pending compaction jobs for Merge-on-Read tables |
| **Data Skew Dashboard** | File and partition size imbalance visualization |
| **Timeline Search** | Searchable history of table operations for debugging |
| **Email Summaries** | Weekly health reports on lakehouse status |
| **Slack Alerts** | Configurable alerts for metric thresholds |
| **Optimization Recs** | Suggestions for clustering, compaction tuning |

| Pricing | Access | Requirements |
|---------|--------|-------------|
| Free | Contact Onehouse | Hudi tables with metadata access |
| No compute cost | No installation | Push metadata to LakeView |
| Zero data access | No pipeline changes | Metadata-only analysis |

## Common Mistakes

### Wrong

```text
Setting up custom Spark jobs to analyze table health.
Querying data files directly to measure data skew.
Building dashboards from scratch for compaction monitoring.
```

### Correct

```text
LakeView reads Hudi metadata (timeline, hoodie.properties)
to provide all monitoring capabilities. No compute clusters
needed. Deploy by pushing metadata -- LakeView handles
analysis, visualization, and alerting automatically.
```

## Related

- [Table Optimizer](../concepts/table-optimizer.md)
- [Platform Architecture](../concepts/platform-architecture.md)
- [Table Optimization Pattern](../patterns/table-optimization.md)
