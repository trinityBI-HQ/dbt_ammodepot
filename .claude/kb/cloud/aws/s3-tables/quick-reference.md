# AWS S3 Tables Quick Reference

> Fast lookup tables. For details, see linked concept/pattern files.

## Core CLI Commands

| Command | Purpose |
|---------|---------|
| `aws s3tables create-table-bucket --name my-bucket` | Create table bucket |
| `aws s3tables create-namespace --table-bucket-arn ARN --namespace ns` | Create namespace |
| `aws s3tables create-table --table-bucket-arn ARN --namespace ns --name tbl --format ICEBERG` | Create table |
| `aws s3tables list-table-buckets` | List table buckets |
| `aws s3tables list-namespaces --table-bucket-arn ARN` | List namespaces |
| `aws s3tables list-tables --table-bucket-arn ARN --namespace ns` | List tables |
| `aws s3tables get-table --table-bucket-arn ARN --namespace ns --name tbl` | Get table details |
| `aws s3tables get-table-metadata-location --table-bucket-arn ARN --namespace ns --name tbl` | Get Iceberg metadata |

## Core boto3 Operations

| Operation | Method | Key Args |
|-----------|--------|----------|
| Create table bucket | `s3tables.create_table_bucket()` | `name` |
| Create namespace | `s3tables.create_namespace()` | `tableBucketARN, namespace` |
| Create table | `s3tables.create_table()` | `tableBucketARN, namespace, name, format` |
| Configure compaction | `s3tables.put_table_maintenance_configuration()` | `type='icebergCompaction'` |
| Configure snapshots | `s3tables.put_table_maintenance_configuration()` | `type='icebergSnapshotManagement'` |

## Hierarchy

```
Table Bucket (10 per region)
  └── Namespace (maps to Glue database)
       └── Table (10,000 per bucket, Apache Iceberg format)
```

## S3 Tables vs Self-Managed Iceberg

| Aspect | S3 Tables | Self-Managed |
|--------|-----------|-------------|
| Compaction | Automatic | Manual Spark/Flink jobs |
| Snapshot cleanup | Automatic | Manual `expire_snapshots` |
| Catalog | Built-in Glue integration | Glue Catalog or HMS |
| Query throughput | Up to 3x faster | Baseline |
| TPS | Up to 10x higher | Baseline |
| Pricing | S3 Tables pricing | Standard S3 pricing |

## Maintenance Defaults

| Setting | Default | Range |
|---------|---------|-------|
| Compaction target file size | 512 MB | 64-512 MB |
| Compaction strategy | auto | auto, binpack, sort, z-order |
| Sort/z-order compaction | Jun 2025 | Automated or on-demand |
| Min snapshots to keep | 1 | 1+ |
| Max snapshot age | 72 hours | Configurable |
| Unreferenced file removal | Enabled | Days configurable |

## Recent Features (2025)

| Feature | Date | Details |
|---------|------|---------|
| Iceberg V3 support | Nov 2025 | Deletion vectors, variant/geometry types |
| Intelligent-Tiering | Dec 2025 | Auto-tier data for cost optimization |
| Cross-region replication | Dec 2025 | Read-only replicas, cross-account |
| Sort/z-order compaction | Jun 2025 | Automated or on-demand |
| SageMaker Unified Studio | 2025 | Notebook-based analytics integration |

## Supported Query Engines

| Engine | Read | Write | Create Table |
|--------|------|-------|-------------|
| Amazon Athena | Yes | Yes (CTAS) | Yes |
| Amazon Redshift | Yes | Yes | No |
| Amazon EMR (Spark) | Yes | Yes | Yes |
| AWS Glue (Spark) | Yes | Yes | Yes |
| Apache Spark (PyIceberg) | Yes | Yes | Yes |
| Snowflake (via Glue IRCC) | Yes | No | No |

## IAM Namespace

S3 Tables uses `s3tables:*` actions (not `s3:*`):

| Action | Purpose |
|--------|---------|
| `s3tables:CreateTableBucket` | Create table bucket |
| `s3tables:CreateNamespace` | Create namespace |
| `s3tables:CreateTable` | Create table |
| `s3tables:GetTableMetadataLocation` | Read Iceberg metadata |
| `s3tables:PutTableMaintenanceConfiguration` | Configure maintenance |

## Related

| Topic | Path |
|-------|------|
| Getting Started | `concepts/table-buckets-namespaces.md` |
| Full Index | `index.md` |
| S3 (general) | `../s3/` |
