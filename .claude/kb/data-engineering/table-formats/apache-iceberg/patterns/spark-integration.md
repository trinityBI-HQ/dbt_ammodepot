# Spark Integration

> **Purpose**: Complete guide to reading, writing, and managing Iceberg tables with Spark
> **MCP Validated**: 2026-02-19

## When to Use

- Building lakehouse pipelines with PySpark or Spark SQL
- Need MERGE INTO for upserts, schema evolution, or time travel
- Multi-engine architecture (Spark writes, Trino/Flink reads)

## Setup & Configuration

### Spark Session Configuration

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("iceberg-app") \
    .config("spark.jars.packages",
            "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0") \
    .config("spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
    .config("spark.sql.catalog.my_catalog",
            "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.my_catalog.type", "rest") \
    .config("spark.sql.catalog.my_catalog.uri", "http://rest-catalog:8181") \
    .config("spark.sql.catalog.my_catalog.warehouse", "s3://my-bucket/warehouse") \
    .config("spark.sql.defaultCatalog", "my_catalog") \
    .getOrCreate()
```

### spark-submit / spark-sql

```bash
spark-sql \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.my_catalog=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.my_catalog.type=rest \
  --conf spark.sql.catalog.my_catalog.uri=http://rest-catalog:8181
```

## DDL — Create & Alter Tables

```sql
-- Create table with partitioning and sort order
CREATE TABLE my_catalog.db.events (
    event_id    BIGINT,
    user_id     BIGINT,
    event_type  STRING,
    payload     STRING,
    ts          TIMESTAMP
)
USING iceberg
PARTITIONED BY (day(ts), bucket(16, user_id))
TBLPROPERTIES (
    'write.sort-order' = 'event_type ASC, ts DESC',
    'write.parquet.compression-codec' = 'zstd'
);

-- Schema evolution
ALTER TABLE my_catalog.db.events ADD COLUMNS (source STRING);
ALTER TABLE my_catalog.db.events RENAME COLUMN payload TO event_payload;
ALTER TABLE my_catalog.db.events DROP COLUMN source;

-- Partition evolution
ALTER TABLE my_catalog.db.events REPLACE PARTITION FIELD day(ts) WITH hour(ts);
```

## DML — Read & Write

### INSERT

```sql
-- Insert values
INSERT INTO my_catalog.db.events VALUES
  (1, 100, 'click', '{}', current_timestamp()),
  (2, 101, 'view',  '{}', current_timestamp());

-- Insert from query
INSERT INTO my_catalog.db.events
SELECT * FROM staging.events WHERE ts > '2026-02-11';
```

### MERGE INTO (Upsert)

```sql
MERGE INTO my_catalog.db.events t
USING (SELECT * FROM staging.updates) s
ON t.event_id = s.event_id
WHEN MATCHED THEN
  UPDATE SET t.event_type = s.event_type, t.payload = s.payload
WHEN NOT MATCHED THEN
  INSERT (event_id, user_id, event_type, payload, ts)
  VALUES (s.event_id, s.user_id, s.event_type, s.payload, s.ts);
```

### UPDATE & DELETE

```sql
-- Row-level update (Iceberg rewrites only affected data files)
UPDATE my_catalog.db.events SET event_type = 'converted' WHERE event_type = 'click' AND ts < '2026-01-01';

-- Row-level delete
DELETE FROM my_catalog.db.events WHERE ts < '2025-01-01';
```

### DataFrame API

```python
# Read
df = spark.table("my_catalog.db.events")

# Read with time travel
df = spark.read \
    .option("snapshot-id", 10963874102873) \
    .format("iceberg") \
    .load("my_catalog.db.events")

# Write (append)
df.writeTo("my_catalog.db.events").append()

# Write (overwrite matching partitions)
df.writeTo("my_catalog.db.events").overwritePartitions()

# Create or replace table
df.writeTo("my_catalog.db.events") \
    .tableProperty("write.parquet.compression-codec", "zstd") \
    .partitionedBy("day(ts)") \
    .createOrReplace()
```

## Metadata Queries

```sql
-- Snapshot history
SELECT * FROM my_catalog.db.events.snapshots;

-- Data file listing
SELECT file_path, record_count, file_size_in_bytes
FROM my_catalog.db.events.files;

-- Partition listing
SELECT * FROM my_catalog.db.events.partitions;

-- Changelog (incremental reads)
SELECT * FROM my_catalog.db.events.changes;
```

## Configuration

| Property | Default | Description |
|----------|---------|-------------|
| `write.parquet.compression-codec` | `gzip` | Parquet compression (zstd recommended) |
| `write.target-file-size-bytes` | `536870912` (512MB) | Target output file size |
| `write.distribution-mode` | `none` | `hash`, `range`, or `none` |
| `write.sort-order` | none | Default sort for written files |
| `read.split.target-size` | `134217728` (128MB) | Spark split size for reads |

## See Also

- [Catalog](../concepts/catalog.md) — catalog configuration options
- [Table Maintenance](../patterns/table-maintenance.md) — compaction and cleanup
- [Performance Tuning](../patterns/performance-tuning.md) — optimizing queries
