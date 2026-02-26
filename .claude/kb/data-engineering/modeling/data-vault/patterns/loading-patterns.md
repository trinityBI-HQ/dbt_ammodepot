# Loading Patterns

> **Purpose**: Strategies for loading data into Hub, Link, and Satellite entities
> **MCP Validated**: 2026-02-19

## Loading Order

```text
1. Stage source data (compute hashes, normalize, prepare)
2. Load Hubs (business keys, dedup on hash key)
3. Load Links (relationships, dedup on composite hash key)
4. Load Satellites (descriptive data, dedup on hashdiff)
```

Steps 2-4 can run **in parallel across different entities** thanks to hash keys. Within each step, entities of the same type are also parallelizable.

## Staging Preparation

Before loading the vault, prepare staging with pre-computed hashes:

```sql
-- Staging view/table that prepares data for vault loading
CREATE VIEW staging.v_stg_orders_prepared AS
SELECT
    -- Hub hash keys
    MD5(UPPER(TRIM(COALESCE(customer_id, '-1'))))  AS hub_customer_hk,
    MD5(UPPER(TRIM(COALESCE(order_id, '-1'))))      AS hub_order_hk,

    -- Link hash key
    MD5(CONCAT(
        COALESCE(MD5(UPPER(TRIM(COALESCE(customer_id, '-1')))), '-1'), '||',
        COALESCE(MD5(UPPER(TRIM(COALESCE(order_id, '-1')))), '-1')
    )) AS lnk_customer_order_hk,

    -- Hashdiff for satellite
    MD5(CONCAT(
        COALESCE(UPPER(TRIM(order_status)), '^^'), '||',
        COALESCE(CAST(order_total AS VARCHAR), '^^')
    )) AS hashdiff_order_details,

    -- Business keys
    customer_id   AS customer_bk,
    order_id      AS order_bk,

    -- Descriptive attributes (for satellites)
    order_status,
    order_total,

    -- Metadata
    CURRENT_TIMESTAMP() AS load_date,
    'ECOMMERCE'         AS record_source
FROM raw.orders;
```

## Hub Loading

```sql
-- Idempotent: only inserts new business keys
INSERT INTO raw_vault.hub_customer (hub_customer_hk, customer_bk, load_date, record_source)
SELECT DISTINCT
    stg.hub_customer_hk,
    stg.customer_bk,
    stg.load_date,
    stg.record_source
FROM staging.v_stg_orders_prepared stg
LEFT JOIN raw_vault.hub_customer hub
    ON stg.hub_customer_hk = hub.hub_customer_hk
WHERE hub.hub_customer_hk IS NULL;
```

## Link Loading

```sql
-- Idempotent: only inserts new relationships
INSERT INTO raw_vault.lnk_customer_order
SELECT DISTINCT
    stg.lnk_customer_order_hk,
    stg.hub_customer_hk,
    stg.hub_order_hk,
    stg.load_date,
    stg.record_source
FROM staging.v_stg_orders_prepared stg
LEFT JOIN raw_vault.lnk_customer_order lnk
    ON stg.lnk_customer_order_hk = lnk.lnk_customer_order_hk
WHERE lnk.lnk_customer_order_hk IS NULL;
```

## Satellite Loading

```sql
-- Only insert when attributes have changed (hashdiff comparison)
INSERT INTO raw_vault.sat_order_details
SELECT
    stg.hub_order_hk,
    stg.load_date,
    stg.hashdiff_order_details AS hashdiff,
    stg.record_source,
    stg.order_status,
    stg.order_total
FROM staging.v_stg_orders_prepared stg
LEFT JOIN (
    -- Get latest satellite record per entity
    SELECT hub_order_hk, hashdiff,
           ROW_NUMBER() OVER (PARTITION BY hub_order_hk ORDER BY load_date DESC) AS rn
    FROM raw_vault.sat_order_details
) latest ON stg.hub_order_hk = latest.hub_order_hk AND latest.rn = 1
WHERE latest.hashdiff IS NULL                          -- brand new entity
   OR latest.hashdiff != stg.hashdiff_order_details;   -- attributes changed
```

## Full vs Delta Loading

| Strategy | When to Use | How |
|----------|------------|-----|
| **Full load** | Small sources, no CDC | Load all rows, dedup via hash key/hashdiff |
| **Delta/CDC** | Large sources, event streams | Only process new/changed records |
| **Hybrid** | Initial + ongoing | Full load once, then delta ongoing |

Full loads are safe because vault loading is idempotent — existing hubs/links are skipped, unchanged satellites are filtered by hashdiff.

## Parallel Loading Strategy

```text
Source A ──→ [Stage A] ──→ hub_customer  ←── [Stage B] ←── Source B
                      ──→ hub_order
                      ──→ lnk_customer_order
                      ──→ sat_order_details
                      ──→ sat_customer_crm  ←── sat_customer_ecommerce
```

Each hub, link, and satellite can load independently. Hash keys eliminate sequence coordination.

## Error Handling

- **Rejected rows**: Log to an error table with source, timestamp, reason
- **Late-arriving data**: Simply insert — load_date captures when it arrived
- **Duplicate detection**: Hash key dedup handles naturally
- **Schema changes**: Add new satellite or new columns to existing satellite (never alter hub/link)

## Performance Tips

- Pre-compute all hashes in staging (not during vault INSERT)
- Use MERGE instead of INSERT...LEFT JOIN on large tables
- Partition satellites by `load_date` for faster latest-record lookups
- Consider materialized views for "current state" queries on satellites

## See Also

- [business-vault.md](business-vault.md) — Derived tables built on raw vault
- [dbt-integration.md](dbt-integration.md) — Automated loading with dbt
- [../concepts/hash-keys.md](../concepts/hash-keys.md) — Hash computation details
