# Satellites

> **Purpose**: Descriptive attributes and temporal history for Hubs and Links
> **MCP Validated**: 2026-02-19

## Overview

A Satellite stores **descriptive context** that changes over time. Every change creates a new row, providing a complete audit trail. Satellites attach to either a Hub or a Link — never to another Satellite.

## Structure

| Column | Type | Description |
|--------|------|-------------|
| `hub/lnk_hk` | BINARY/VARCHAR | FK to parent hub or link (PK part 1) |
| `load_date` | TIMESTAMP | When this version was loaded (PK part 2) |
| `hashdiff` | BINARY/VARCHAR | Hash of all descriptive columns (change detection) |
| `record_source` | VARCHAR | Source system identifier |
| `<attributes>` | Various | Descriptive columns (name, address, status, etc.) |

**Composite PK**: `(parent_hk, load_date)` — one row per entity per change.

## Types of Satellites

### Hub Satellite (most common)

Descriptive data about a business entity.

```sql
CREATE TABLE raw_vault.sat_customer_details (
    hub_customer_hk  BINARY(16)   NOT NULL,
    load_date        TIMESTAMP    NOT NULL,
    hashdiff         BINARY(16)   NOT NULL,
    record_source    VARCHAR(50)  NOT NULL,
    first_name       VARCHAR(100),
    last_name        VARCHAR(100),
    email            VARCHAR(255),
    phone            VARCHAR(50),
    CONSTRAINT pk_sat_customer PRIMARY KEY (hub_customer_hk, load_date)
);
```

### Link Satellite

Descriptive data about a relationship (e.g., order details on a customer-order link).

```sql
CREATE TABLE raw_vault.sat_customer_order_details (
    lnk_customer_order_hk  BINARY(16)   NOT NULL,
    load_date              TIMESTAMP    NOT NULL,
    hashdiff               BINARY(16)   NOT NULL,
    record_source          VARCHAR(50)  NOT NULL,
    order_status           VARCHAR(20),
    shipping_method        VARCHAR(50),
    CONSTRAINT pk_sat_co PRIMARY KEY (lnk_customer_order_hk, load_date)
);
```

### Effectivity Satellite

Tracks when a Link relationship starts and ends.

```sql
CREATE TABLE raw_vault.sat_customer_order_eff (
    lnk_customer_order_hk  BINARY(16)  NOT NULL,
    load_date              TIMESTAMP   NOT NULL,
    record_source          VARCHAR(50) NOT NULL,
    start_date             TIMESTAMP   NOT NULL,
    end_date               TIMESTAMP,           -- NULL = currently active
    CONSTRAINT pk_sat_co_eff PRIMARY KEY (lnk_customer_order_hk, load_date)
);
```

### Multi-Active Satellite

Multiple active rows per parent at the same time (e.g., phone numbers, addresses).

```sql
-- PK includes a sub-sequence key
CONSTRAINT pk_sat_cust_phone PRIMARY KEY (hub_customer_hk, load_date, phone_type)
```

## Loading Pattern

```sql
-- Only insert when hashdiff changes (new or modified data)
INSERT INTO raw_vault.sat_customer_details
SELECT
    src.hub_customer_hk,
    src.load_date,
    src.hashdiff,
    src.record_source,
    src.first_name,
    src.last_name,
    src.email,
    src.phone
FROM staging.stg_crm_customers_prepared src
LEFT JOIN raw_vault.sat_customer_details sat
    ON src.hub_customer_hk = sat.hub_customer_hk
    AND sat.load_date = (
        SELECT MAX(s.load_date)
        FROM raw_vault.sat_customer_details s
        WHERE s.hub_customer_hk = src.hub_customer_hk
    )
WHERE sat.hashdiff IS NULL           -- new entity (no prior satellite row)
   OR sat.hashdiff != src.hashdiff;  -- attribute changed
```

## Split Satellites

Split by **rate of change** or **source system** to reduce row volume:

- `sat_customer_details` — name, email (rarely changes)
- `sat_customer_status` — status, tier (changes frequently)
- `sat_customer_crm` / `sat_customer_ecommerce` — source-specific fields

## Rules

- **Insert-only**: Never update or delete satellite rows
- **Hashdiff drives loading**: Only insert when attributes actually change
- **One source per satellite** (recommended): Avoids mixed-source confusion
- **Split by change frequency**: Avoid unnecessary row duplication

## Common Mistakes

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| No hashdiff check | Duplicates identical rows | Always compare hashdiff |
| Updating existing rows | Breaks audit trail | Insert new row instead |
| One mega-satellite | Row explosion on any change | Split by change rate |
| Missing NULL handling | Inconsistent hash values | Use `COALESCE` with sentinel |

## See Also

- [hubs.md](hubs.md) — Parent entities for hub satellites
- [links.md](links.md) — Parent relationships for link satellites
- [hash-keys.md](hash-keys.md) — Hash key and hashdiff generation
