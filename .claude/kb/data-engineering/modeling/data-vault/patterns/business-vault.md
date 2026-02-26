# Business Vault

> **Purpose**: Derived layer applying business rules on top of Raw Vault
> **MCP Validated**: 2026-02-19

## Overview

The **Raw Vault** is the system of record — zero business rules, full auditability. The **Business Vault** sits on top of the Raw Vault and contains computed/derived data, query-assistance structures, and business interpretations.

```text
Raw Vault (system of record) → Business Vault (derived) → Star Schema Marts (presentation)
```

Business Vault entities are **disposable** — they can always be rebuilt from the Raw Vault.

## Business Vault Components

| Component | Purpose | Prefix |
|-----------|---------|--------|
| PIT Table | Point-in-Time snapshot for efficient satellite joins | `pit_` |
| Bridge Table | Pre-joined link paths for query performance | `br_` |
| Business Satellite | Computed/derived attributes | `bsat_` |
| Computed Link | Derived relationships not in source | `clnk_` |
| Reference Table | Shared lookups (countries, currencies) | `ref_` |

## PIT Tables (Point-in-Time)

### Problem

Querying a hub with multiple satellites at a specific point in time requires complex temporal joins for each satellite.

### Solution

A PIT table pre-computes which satellite record was active at each snapshot point.

```sql
CREATE TABLE business_vault.pit_customer (
    hub_customer_hk           BINARY(16)  NOT NULL,
    snapshot_date             DATE        NOT NULL,
    sat_customer_details_hk   BINARY(16),  -- FK to sat row active at snapshot
    sat_customer_details_ldts TIMESTAMP,   -- load_date of active sat row
    sat_customer_status_hk    BINARY(16),
    sat_customer_status_ldts  TIMESTAMP,
    CONSTRAINT pk_pit_customer PRIMARY KEY (hub_customer_hk, snapshot_date)
);
```

### Loading a PIT Table

```sql
-- For each hub entity and each snapshot date, find the latest satellite record
INSERT INTO business_vault.pit_customer
SELECT
    hub.hub_customer_hk,
    snap.snapshot_date,
    -- Details satellite: latest load_date <= snapshot_date
    det.hub_customer_hk  AS sat_customer_details_hk,
    det.load_date        AS sat_customer_details_ldts,
    -- Status satellite
    sts.hub_customer_hk  AS sat_customer_status_hk,
    sts.load_date        AS sat_customer_status_ldts
FROM raw_vault.hub_customer hub
CROSS JOIN date_spine snap  -- daily/hourly/etc.
LEFT JOIN LATERAL (
    SELECT hub_customer_hk, load_date
    FROM raw_vault.sat_customer_details
    WHERE hub_customer_hk = hub.hub_customer_hk
      AND load_date <= snap.snapshot_date
    ORDER BY load_date DESC LIMIT 1
) det ON TRUE
LEFT JOIN LATERAL (
    SELECT hub_customer_hk, load_date
    FROM raw_vault.sat_customer_status
    WHERE hub_customer_hk = hub.hub_customer_hk
      AND load_date <= snap.snapshot_date
    ORDER BY load_date DESC LIMIT 1
) sts ON TRUE;
```

### When to Use PIT

- Hub has 2+ satellites that must be joined together
- Frequent point-in-time or as-of-date queries
- BI tools querying across multiple satellite attributes

## Bridge Tables

### Problem

Traversing multi-hop link paths (customer → order → product) requires multiple joins.

### Solution

A Bridge table pre-joins a common traversal path.

```sql
CREATE TABLE business_vault.br_customer_order_product (
    hub_customer_hk  BINARY(16)  NOT NULL,
    hub_order_hk     BINARY(16)  NOT NULL,
    hub_product_hk   BINARY(16)  NOT NULL,
    load_date        TIMESTAMP   NOT NULL
);
```

### When to Use Bridge

- Repeated multi-hop joins in downstream queries
- Star schema mart construction from deep vault paths
- Performance-critical reporting queries

## Business Satellites

Derived attributes computed from Raw Vault data:

```sql
-- Customer classification based on order history
CREATE TABLE business_vault.bsat_customer_classification (
    hub_customer_hk     BINARY(16)   NOT NULL,
    load_date           TIMESTAMP    NOT NULL,
    hashdiff            BINARY(16)   NOT NULL,
    record_source       VARCHAR(50)  DEFAULT 'BUSINESS_VAULT',
    total_orders        INTEGER,
    total_revenue       DECIMAL(18,2),
    customer_tier       VARCHAR(20),   -- 'GOLD', 'SILVER', 'BRONZE'
    lifetime_value      DECIMAL(18,2),
    CONSTRAINT pk_bsat_cust_class PRIMARY KEY (hub_customer_hk, load_date)
);
```

### Business Satellite Rules

- Same structure as Raw Vault satellites (hashdiff, load_date, record_source)
- `record_source` = `'BUSINESS_VAULT'` to distinguish from raw data
- **Rebuildable**: Can always be recreated from Raw Vault
- Contains **business logic** (aggregations, calculations, classifications)

## Raw Vault vs Business Vault

| Aspect | Raw Vault | Business Vault |
|--------|-----------|----------------|
| Business rules | None | Applied |
| Source of truth | Yes | No (derived) |
| Rebuildable | From source | From Raw Vault |
| Modifiable | Never | Can be dropped/rebuilt |
| Audit trail | Complete | Inherited |
| Performance optimized | No | Yes (PIT, Bridge) |

## Architecture Decision

```text
Simple queries (few satellites)  → Query Raw Vault directly
Multi-satellite joins            → Add PIT table
Multi-hop link traversal         → Add Bridge table
Computed metrics/classifications → Add Business Satellite
Presentation to BI tools         → Build Star Schema marts
```

## See Also

- [loading-patterns.md](loading-patterns.md) — Raw Vault loading
- [dbt-integration.md](dbt-integration.md) — Building Business Vault with dbt
- [../concepts/satellites.md](../concepts/satellites.md) — Satellite fundamentals
