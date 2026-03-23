# MWAA Archive (Deleted 2026-03-23)

## Why Deleted
- `DBT_PROCESS_SIMPLIFIED` replaced by ECS Fargate (dbt orchestration)
- `LISTRAK_INCREMENTAL_V2` no longer needed (Listrak data not used in reporting)
- MWAA cost: ~$400-500/mo for 2 DAGs

## Files
- `DBT_PROCESS_S.py` — Old dbt/Airbyte orchestration DAG (every 70 min, Redshift)
- `listrak.py` — Listrak API → Redshift ETL (daily at 2 AM, incremental)
- `mwaa-config-backup.json` — Full MWAA environment config for restoration

## Restoration
If Listrak data is needed again, migrate to ECS scheduled task or Lambda instead of recreating MWAA.

## S3 Bucket
DAGs were stored in: `s3://airflow-dags-bucket-2025/dags/`
