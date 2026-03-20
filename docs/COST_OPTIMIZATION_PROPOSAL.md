# AWS Cost Optimization Proposal

## Executive Summary

Our infrastructure audit identified **~$27,400 in annual savings** by eliminating redundant services after completing the Snowflake migration. The current architecture runs parallel systems (Redshift + Snowflake) that will be consolidated into a single, more efficient stack.

| Service | Current Monthly Cost | Proposed | Savings |
|---|---|---|---|
| Amazon Redshift (2x ra3.large) | $793 | Eliminate | **$793/mo** |
| Amazon MWAA (mw1.large) | $1,205 | Eliminate | **$1,205/mo** |
| EC2 Airbyte (c6i.4xlarge) | $496 | Downsize to c6i.2xlarge | **$248/mo** |
| dbt Cloud (Starter, 1 seat) | ~$140 | Optimize run frequency | **~$40/mo** |
| **Total** | **~$2,634/mo** | | **~$2,286/mo saved** |

**Annual savings: ~$27,434**

---

## 1. Eliminate Amazon Redshift — $793/month

### Current State

| Attribute | Value |
|---|---|
| Cluster | `airbyte-project-redshift-cluster` |
| Node type | ra3.large (2 nodes) |
| Cost | $0.543/hr/node x 2 = $1.086/hr |
| Storage used | 119.6 GB of 15.3 TB (**0.77%**) |
| Created | June 9, 2025 |
| Pricing | On-Demand (no Reserved Instances) |

### Why It Can Be Eliminated

- All 119.6 GB of data is already replicated to Snowflake via Airbyte
- The Snowflake project (`ammodepot/`) has 99 models — all passing, including 3 new Gold models not in Redshift
- Power BI can connect directly to Snowflake (`SVC_POWERBI` already configured)
- Streamlit dashboard already reads from Snowflake
- Storage utilization at 0.77% means the cluster is massively over-provisioned even for its current workload

### Prerequisites

1. Migrate remaining Power BI dataflows from Redshift to Snowflake
2. Switch dbt Cloud project from `projects/ammodepot` (Redshift) to `ammodepot` (Snowflake)
3. Disable Airbyte connections #1, #2, and #5 (Redshift-targeted)
4. Verify no other services depend on the cluster

---

## 2. Eliminate Amazon MWAA — $1,205/month

### Current State

| Attribute | Value |
|---|---|
| Environment | mw1.large (Airflow 2.10.3) |
| Schedulers | 2 |
| Workers | 1 min, 10 max |
| Web servers | 2 |
| Active DAGs | 1 of 2 |

**Cost breakdown:**

| Component | Hourly | Monthly |
|---|---|---|
| Environment instance | $0.99 | $723 |
| Schedulers (2x) | $0.44 | $321 |
| Workers (1x min) | $0.22 | $161 |
| **Total** | **$1.65** | **$1,205** |

### DAG Analysis

| DAG | Status | Last Run | Purpose |
|---|---|---|---|
| `DBT_PROCESS_SIMPLIFIED` | **Paused** | Oct 27, 2025 | Was orchestrating Airbyte + dbt runs |
| `LISTRAK_INCREMENTAL_V2` | Active | Daily at 2am | Listrak email API → Redshift |

**`DBT_PROCESS_SIMPLIFIED`** has been paused for 5 months. Its function (orchestrating Airbyte syncs and dbt runs) is now handled by Airbyte's native scheduler and dbt Cloud. This DAG is dead weight.

**`LISTRAK_INCREMENTAL_V2`** extracts email marketing data from Listrak's API into 5 Redshift tables. However:
- It writes **exclusively to Redshift** — it cannot survive the cluster termination
- The associated Power BI report ("LISTRAK OVERVIEW") shows broken refresh warnings
- It has hardcoded API credentials in the source code (security risk)

### Why It Can Be Eliminated

The entire MWAA environment exists to run a single daily ETL job that:
1. Feeds data into a cluster being terminated
2. Powers a report that appears to be broken
3. Costs $1,205/month — approximately **40x more** than the workload requires

### If Listrak Data Is Still Needed

If the email marketing data remains a business requirement, we recommend replacing the MWAA DAG with one of these alternatives:

| Option | Effort | Incremental Cost | Notes |
|---|---|---|---|
| **Airbyte custom connector** | Medium | $0 | Runs on existing EC2, writes to Snowflake |
| **EC2 cron script** | Low | $0 | Python script on existing Airbyte EC2 |
| **AWS Lambda** | Low | ~$1/mo | Serverless, pay-per-invocation |

All options target Snowflake instead of Redshift and cost effectively nothing compared to $1,205/month.

---

## 3. Downsize EC2 Instance — $248/month

### Current State

| Attribute | Current | Proposed |
|---|---|---|
| Instance type | c6i.4xlarge | c6i.2xlarge |
| vCPUs | 16 (8 cores) | 8 (4 cores) |
| Memory | 32 GB | 16 GB |
| Network | Up to 12.5 Gbps | Up to 12.5 Gbps |
| Hourly cost | $0.680 | $0.340 |
| Monthly cost | $496 | $248 |

### Why It Can Be Downsized

The EC2 instance runs Airbyte (self-hosted via Kind/Kubernetes). Currently it handles 7 connections writing to two warehouses. After consolidation:

- Airbyte connections drop from 7 to 2-3 (Snowflake-only)
- Redshift dual-write overhead eliminated
- 8 vCPUs and 16 GB RAM is sufficient for the remaining workload
- Network performance is identical (12.5 Gbps)
- EBS storage (600 GB) is unchanged

### How to Downsize

1. Stop the EC2 instance
2. Change instance type to c6i.2xlarge
3. Start the instance
4. Airbyte resumes syncs automatically

Downtime: ~2-3 minutes.

---

## 4. Optimize dbt Cloud — ~$40/month

### Current State

- **Plan:** Starter ($100/month, 1 developer seat)
- **Included:** 15,000 successful models/month
- **Overage:** $0.01 per additional model
- **Recent usage:** 15,000-22,000 models/month (overages of $30-70)

### Optimization

After migrating to the Snowflake project, review scheduled run frequency:
- Not all models need hourly refreshes
- Reducing frequency for stable dimension tables can keep usage under 15,000 models/month
- Estimated savings: ~$40/month in overage charges

---

## Implementation Sequence

```
Phase 1: Validate & Prepare
├── Confirm Listrak data business requirement with stakeholders
├── If needed, build replacement extraction (Airbyte/cron/Lambda → Snowflake)
└── Verify all Power BI reports work against Snowflake

Phase 2: Migrate
├── Switch dbt Cloud project to Snowflake (`ammodepot/`)
├── Migrate Power BI dataflows to Snowflake
└── Validate data quality and report accuracy

Phase 3: Decommission
├── Disable Redshift Airbyte connections (#1, #2, #5)
├── Terminate MWAA environment
├── Downsize EC2 to c6i.2xlarge
├── Keep Redshift cluster stopped for 30 days (safety net)
└── Terminate Redshift cluster

Phase 4: Optimize
├── Tune dbt Cloud run frequency
└── Snowflake warehouse optimization (see below)
```

---

## 5. Snowflake Warehouse Optimization (Completed 2026-03-20)

### Changes Applied

| Change | Before | After | Impact |
|---|---|---|---|
| Airbyte sync frequency (FB→SF) | 5 min | 10 min | ~50% fewer warehouse wake-ups |
| Airbyte sync frequency (MG→SF) | 5 min | 10 min | Eliminates sync overlap (syncs took 5-7 min on 5-min interval) |
| ETL_WH auto-suspend | 120s | 60s | ~15-20% idle credit reduction |

### Pending

| Change | Description | Status |
|---|---|---|
| Create `BI_WH` | Dedicated XS warehouse for Power BI, Streamlit, dashboard viewers | Planned |
| Revoke BI roles from `ETL_WH` | Separate ingestion/transform from BI query workloads | Planned |
| Power BI refresh schedule review | 19 refreshes/day, gap during business hours (8:30 AM–5 PM ET) | Under investigation |

### Risk Mitigation

- **Redshift safety net:** Stop (don't terminate) the cluster for 30 days after migration. Snapshots are retained. Resume only if issues are discovered.
- **Listrak data:** If stakeholders confirm the data is needed, build the replacement extraction *before* terminating MWAA.
- **EC2 downsize:** Fully reversible — can change instance type back in 2 minutes if performance issues arise.

---

## Summary

| Metric | Value |
|---|---|
| Services eliminated | 2 (Redshift, MWAA) |
| Services downsized | 1 (EC2) |
| Services optimized | 1 (dbt Cloud) |
| Monthly savings | ~$2,286 |
| Annual savings | ~$27,434 |
| Implementation risk | Low (all changes reversible) |
