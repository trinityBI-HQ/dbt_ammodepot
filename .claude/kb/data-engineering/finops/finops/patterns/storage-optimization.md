# Storage Cost Optimization

> **Purpose**: Reduce storage costs through lifecycle policies, tiering, compaction, and retention management
> **MCP Validated**: 2026-02-19

## When to Use

- Storage costs are growing faster than data value
- All data sits in hot storage tiers regardless of access frequency
- No lifecycle policies exist on S3/GCS buckets
- Delta/Iceberg tables have small file problems
- Pipeline staging data is never cleaned up
- Dev/test data persists indefinitely

## S3 Lifecycle Policies

### Standard Data Engineering Lifecycle

```json
{
  "Rules": [
    {
      "ID": "pipeline-staging-cleanup",
      "Status": "Enabled",
      "Filter": {"Prefix": "staging/"},
      "Expiration": {"Days": 7}
    },
    {
      "ID": "bronze-tier-transition",
      "Status": "Enabled",
      "Filter": {"Prefix": "bronze/"},
      "Transitions": [
        {"Days": 30, "StorageClass": "STANDARD_IA"},
        {"Days": 90, "StorageClass": "GLACIER_IR"},
        {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
      ]
    },
    {
      "ID": "silver-tier-transition",
      "Status": "Enabled",
      "Filter": {"Prefix": "silver/"},
      "Transitions": [
        {"Days": 90, "StorageClass": "STANDARD_IA"},
        {"Days": 365, "StorageClass": "GLACIER_IR"}
      ]
    },
    {
      "ID": "gold-keep-hot",
      "Status": "Enabled",
      "Filter": {"Prefix": "gold/"},
      "Transitions": [
        {"Days": 180, "StorageClass": "STANDARD_IA"}
      ]
    },
    {
      "ID": "cleanup-incomplete-uploads",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 3}
    },
    {
      "ID": "expire-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionTransitions": [
        {"NoncurrentDays": 30, "StorageClass": "STANDARD_IA"}
      ],
      "NoncurrentVersionExpiration": {"NoncurrentDays": 90}
    }
  ]
}
```

### GCS Lifecycle (Equivalent)

```json
{"lifecycle": {"rule": [
  {"action": {"type": "SetStorageClass", "storageClass": "NEARLINE"}, "condition": {"age": 30, "matchesPrefix": ["bronze/"]}},
  {"action": {"type": "SetStorageClass", "storageClass": "COLDLINE"}, "condition": {"age": 90, "matchesPrefix": ["bronze/"]}},
  {"action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"}, "condition": {"age": 365, "matchesPrefix": ["bronze/"]}},
  {"action": {"type": "Delete"}, "condition": {"age": 7, "matchesPrefix": ["staging/", "tmp/"]}}
]}}
```

## S3 Intelligent-Tiering

Use when access patterns are unpredictable. Small monitoring fee ($0.0025/1K objects) but fully automatic tiering.

## Delta Lake / Iceberg Compaction

### Delta Table Maintenance

```python
# Databricks: Optimize small files and vacuum old versions
from delta.tables import DeltaTable

# Compact small files (critical for query performance and cost)
spark.sql("OPTIMIZE delta.`s3://bucket/bronze/events`")

# Z-ORDER by common filter columns
spark.sql("""
    OPTIMIZE delta.`s3://bucket/silver/orders`
    ZORDER BY (customer_id, order_date)
""")

# Vacuum old files (default 7-day retention)
delta_table = DeltaTable.forPath(spark, "s3://bucket/bronze/events")
delta_table.vacuum(168)  # 168 hours = 7 days
```

### Iceberg Table Maintenance

```sql
-- Compact small files
CALL system.rewrite_data_files(
    table => 'catalog.db.events',
    options => map('target-file-size-bytes', '134217728')  -- 128 MB
);

-- Remove old snapshots (reduce metadata and storage)
CALL system.expire_snapshots(
    table => 'catalog.db.events',
    older_than => TIMESTAMP '2025-01-01 00:00:00',
    retain_last => 5
);

-- Remove orphan files
CALL system.remove_orphan_files(
    table => 'catalog.db.events',
    older_than => TIMESTAMP '2025-01-01 00:00:00'
);
```

## Storage Cost Monitoring

```sql
-- AWS S3 Storage Lens: Enable at organization level for free tier metrics
-- Key metrics to track:
--   - Total storage by prefix (bronze/, silver/, gold/)
--   - Storage class distribution (% in Standard vs IA vs Glacier)
--   - Incomplete multipart uploads (hidden cost)
--   - Average object size (small files = more requests = more cost)
```

## Configuration Reference

| Setting | Recommendation | Impact |
|---------|---------------|--------|
| Bronze lifecycle | Standard 30d, IA 90d, Glacier 365d | 60-80% savings on old data |
| Staging cleanup | Delete after 7 days | Prevents unbounded growth |
| Multipart abort | 3 days | Eliminates hidden storage cost |
| Version expiry | 90 days | Prevents version bloat |
| Delta OPTIMIZE | Weekly for active tables | Reduces query scan cost |
| Iceberg compaction | Daily/weekly for active tables | 128 MB target file size |
| Intelligent-Tiering | Unknown access patterns | Automatic, small monitoring fee |

## See Also

- [Cloud Billing](../concepts/cloud-billing.md) -- Storage pricing by class
- [Monitoring and Alerting](monitoring-alerting.md) -- Storage cost dashboards
- [Data Pipeline Optimization](data-pipeline-optimization.md) -- Compute for compaction jobs
