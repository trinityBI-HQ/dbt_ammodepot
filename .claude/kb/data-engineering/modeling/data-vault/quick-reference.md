# Data Vault 2.0 Quick Reference

> **Purpose**: Fast lookup for Data Vault entities, columns, and naming
> **MCP Validated**: 2026-02-19

## Entity Types

| Entity | Purpose | Key Columns | Grain |
|--------|---------|-------------|-------|
| Hub | Business key | hash_key, bk, load_date, record_source | One row per unique business key |
| Link | Relationship | hash_key, hub_hk_1, hub_hk_2, load_date, record_source | One row per unique relationship |
| Satellite | Context/history | hash_key (FK), hashdiff, load_date, record_source, attributes | One row per change |

## Required Columns

### Hub

| Column | Type | Description |
|--------|------|-------------|
| `hub_<entity>_hk` | BINARY/VARCHAR | Hash of business key (PK) |
| `<entity>_bk` | VARCHAR | Natural business key |
| `load_date` | TIMESTAMP | When first loaded |
| `record_source` | VARCHAR | Source system identifier |

### Link

| Column | Type | Description |
|--------|------|-------------|
| `lnk_<relationship>_hk` | BINARY/VARCHAR | Hash of all hub HKs (PK) |
| `hub_<entity1>_hk` | BINARY/VARCHAR | FK to hub 1 |
| `hub_<entity2>_hk` | BINARY/VARCHAR | FK to hub 2 |
| `load_date` | TIMESTAMP | When first loaded |
| `record_source` | VARCHAR | Source system identifier |

### Satellite

| Column | Type | Description |
|--------|------|-------------|
| `hub/lnk_hk` | BINARY/VARCHAR | FK to parent hub or link (PK part 1) |
| `load_date` | TIMESTAMP | When this version loaded (PK part 2) |
| `hashdiff` | BINARY/VARCHAR | Hash of all descriptive columns |
| `record_source` | VARCHAR | Source system identifier |
| `<attributes>` | Various | Descriptive columns |

## Naming Conventions

| Entity | Prefix | Example |
|--------|--------|---------|
| Hub | `hub_` | `hub_customer`, `hub_order` |
| Link | `lnk_` | `lnk_customer_order` |
| Satellite | `sat_` | `sat_customer_details`, `sat_order_stripe` |
| PIT table | `pit_` | `pit_customer` |
| Bridge table | `br_` | `br_customer_order` |
| Business Sat | `bsat_` | `bsat_customer_classification` |

## Hash Key Formulas

```sql
-- Single business key
MD5(UPPER(TRIM(COALESCE(customer_id, '-1'))))

-- Composite business key (link)
MD5(CONCAT(
    COALESCE(hub_customer_hk, '-1'), '||',
    COALESCE(hub_order_hk, '-1')
))

-- Hashdiff (satellite change detection)
MD5(CONCAT(
    COALESCE(UPPER(TRIM(first_name)), '^^'), '||',
    COALESCE(UPPER(TRIM(last_name)), '^^'), '||',
    COALESCE(UPPER(TRIM(email)), '^^')
))
```

## Loading Rules

| Rule | Description |
|------|-------------|
| Hubs first | Always load hubs before links (FK dependency) |
| Insert-only | Never UPDATE or DELETE — only INSERT new rows |
| Idempotent | Re-running a load produces the same result |
| Dedup on load | Check hash key exists before inserting hub/link |
| Hashdiff check | Only insert satellite row if hashdiff changed |
| Parallel load | Hash keys enable loading all entities concurrently |

## DV 2.0 vs DV 1.0

| Feature | DV 1.0 | DV 2.0 |
|---------|--------|--------|
| Keys | Sequences | Hash keys |
| Loading | Sequential | Parallel |
| Methodology | Modeling only | Model + Architecture + Methodology |
| Real-time | Not supported | Supported |
| NoSQL | Not supported | Supported |

## See Also

- [concepts/hubs.md](concepts/hubs.md) | [concepts/links.md](concepts/links.md) | [concepts/satellites.md](concepts/satellites.md)
