# Links

> **Purpose**: Relationships and transactions between two or more Hubs
> **MCP Validated**: 2026-02-19

## Overview

A Link captures a **relationship or event** between business entities. It stores the hash keys of the participating hubs plus its own composite hash key. Like Hubs, Links are insert-only and carry no descriptive attributes.

## Structure

| Column | Type | Description |
|--------|------|-------------|
| `lnk_<relationship>_hk` | BINARY/VARCHAR | Hash of all hub HKs combined (PK) |
| `hub_<entity1>_hk` | BINARY/VARCHAR | FK to first hub |
| `hub_<entity2>_hk` | BINARY/VARCHAR | FK to second hub |
| `load_date` | TIMESTAMP | First time this relationship was seen |
| `record_source` | VARCHAR | Source system identifier |

## Types of Links

### Standard Link (Relationship)

Connects two hubs representing a many-to-many relationship.

```sql
CREATE TABLE raw_vault.lnk_customer_order (
    lnk_customer_order_hk  BINARY(16)  NOT NULL,  -- MD5(hub_customer_hk || hub_order_hk)
    hub_customer_hk         BINARY(16)  NOT NULL,
    hub_order_hk            BINARY(16)  NOT NULL,
    load_date               TIMESTAMP   NOT NULL,
    record_source           VARCHAR(50) NOT NULL,
    CONSTRAINT pk_lnk_customer_order PRIMARY KEY (lnk_customer_order_hk)
);
```

### Multi-Hub Link

Connects three or more hubs (e.g., customer + product + store).

```sql
-- A transaction link connecting customer, product, and store
lnk_purchase_hk = MD5(CONCAT(
    hub_customer_hk, '||',
    hub_product_hk, '||',
    hub_store_hk
))
```

### Same-As Link

Connects two business keys from the same hub (master data management).

```sql
-- Two customer records that represent the same person
CREATE TABLE raw_vault.lnk_customer_same_as (
    lnk_same_as_hk    BINARY(16)  NOT NULL,
    hub_customer_hk_1  BINARY(16)  NOT NULL,  -- master
    hub_customer_hk_2  BINARY(16)  NOT NULL,  -- duplicate
    load_date          TIMESTAMP   NOT NULL,
    record_source      VARCHAR(50) NOT NULL
);
```

### Hierarchical Link

Self-referencing relationship within a single hub (org charts, categories).

```sql
-- Employee reports-to hierarchy
CREATE TABLE raw_vault.lnk_employee_hierarchy (
    lnk_hierarchy_hk       BINARY(16)  NOT NULL,
    hub_employee_hk         BINARY(16)  NOT NULL,  -- child
    hub_employee_parent_hk  BINARY(16)  NOT NULL,  -- parent
    load_date               TIMESTAMP   NOT NULL,
    record_source           VARCHAR(50) NOT NULL
);
```

## Loading Pattern

```sql
INSERT INTO raw_vault.lnk_customer_order
SELECT DISTINCT
    MD5(CONCAT(
        COALESCE(hub_customer_hk, '-1'), '||',
        COALESCE(hub_order_hk, '-1')
    )) AS lnk_customer_order_hk,
    hub_customer_hk,
    hub_order_hk,
    load_date,
    record_source
FROM staging.stg_orders_prepared src
WHERE NOT EXISTS (
    SELECT 1 FROM raw_vault.lnk_customer_order lnk
    WHERE lnk.lnk_customer_order_hk = MD5(CONCAT(
        COALESCE(src.hub_customer_hk, '-1'), '||',
        COALESCE(src.hub_order_hk, '-1')
    ))
);
```

## Rules

- **Load hubs first**: Links reference hub hash keys — hubs must exist
- **Insert-only**: A relationship, once recorded, is never removed
- **No descriptive data**: Context about the relationship goes in Link Satellites
- **Dedup on composite hash**: Same pair of hubs → same link row
- **Effectivity Satellites**: Track when relationships start/end (not in the link itself)

## Common Mistakes

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| Adding attributes to links | Links only hold keys | Use a Link Satellite |
| Deleting ended relationships | Violates insert-only | Use Effectivity Satellite |
| Loading before hubs | FK integrity issues | Always load hubs first |
| Using only one hub's HK as PK | Loses relationship uniqueness | Hash ALL participating hub HKs |

## See Also

- [hubs.md](hubs.md) — Business entities that links connect
- [satellites.md](satellites.md) — Descriptive data for links
- [hash-keys.md](hash-keys.md) — Hash key generation patterns
