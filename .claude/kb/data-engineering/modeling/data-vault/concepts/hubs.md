# Hubs

> **Purpose**: Core business entities identified by their natural business keys
> **MCP Validated**: 2026-02-19

## Overview

A Hub represents a **unique business concept** (customer, order, product, employee). It stores only the business key and metadata — no descriptive attributes. Hubs are the anchor points of the Data Vault model.

## Structure

| Column | Type | Description |
|--------|------|-------------|
| `hub_<entity>_hk` | BINARY/VARCHAR | Hash of business key (PK) |
| `<entity>_bk` | VARCHAR | Natural business key from source |
| `load_date` | TIMESTAMP | First time this key was seen |
| `record_source` | VARCHAR | System that first provided this key |

## Rules

- **Insert-only**: Once a business key is loaded, its hub row never changes
- **One row per business key**: Deduplicate on load
- **No descriptive data**: Names, addresses, statuses go in Satellites
- **No foreign keys to other hubs**: Relationships go in Links
- **load_date is arrival time**, not business event time

## Example: DDL

```sql
CREATE TABLE raw_vault.hub_customer (
    hub_customer_hk  BINARY(16)   NOT NULL,  -- MD5 hash of customer_bk
    customer_bk      VARCHAR(50)  NOT NULL,  -- natural business key
    load_date        TIMESTAMP    NOT NULL,  -- first seen timestamp
    record_source    VARCHAR(50)  NOT NULL,  -- e.g. 'CRM', 'ECOMMERCE'
    CONSTRAINT pk_hub_customer PRIMARY KEY (hub_customer_hk)
);
```

## Example: Loading

```sql
-- Insert only new business keys (idempotent)
INSERT INTO raw_vault.hub_customer (hub_customer_hk, customer_bk, load_date, record_source)
SELECT DISTINCT
    MD5(UPPER(TRIM(src.customer_id)))  AS hub_customer_hk,
    src.customer_id                     AS customer_bk,
    src.load_date,
    src.record_source
FROM staging.stg_crm_customers src
WHERE NOT EXISTS (
    SELECT 1 FROM raw_vault.hub_customer hub
    WHERE hub.hub_customer_hk = MD5(UPPER(TRIM(src.customer_id)))
);
```

## Multi-Source Hubs

When multiple sources provide the same business entity:

```text
CRM System  ──→ hub_customer (customer_bk = 'C001', record_source = 'CRM')
Ecommerce   ──→ hub_customer (customer_bk = 'C001', record_source = 'ECOMMERCE')
                 ↑ Same hash key → only first arrival inserted
```

The first source to provide a business key "wins" the `load_date` and `record_source`. All subsequent sources see the key already exists and skip.

## Composite Business Keys

Some entities require multiple columns to form a unique business key:

```sql
-- Order line item needs both order_id + line_number
hub_order_line_hk = MD5(CONCAT(
    COALESCE(UPPER(TRIM(order_id)), '-1'), '||',
    COALESCE(UPPER(TRIM(line_number)), '-1')
))
```

Store all component columns as separate `_bk` fields in the hub.

## Common Mistakes

| Mistake | Why It's Wrong | Fix |
|---------|---------------|-----|
| Adding descriptive columns | Hubs only hold keys | Move to Satellite |
| Using sequence IDs as PK | Can't parallel load | Use hash keys |
| Updating load_date | Violates insert-only | load_date is immutable |
| Skipping record_source | Loses auditability | Always track source |

## See Also

- [links.md](links.md) — Relationships between hubs
- [satellites.md](satellites.md) — Descriptive data attached to hubs
- [hash-keys.md](hash-keys.md) — Hash key generation
