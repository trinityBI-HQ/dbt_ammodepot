# Hash Keys

> **Purpose**: Deterministic, reproducible keys that enable parallel loading
> **MCP Validated**: 2026-02-19

## Overview

Data Vault 2.0 replaced sequence-based keys (DV 1.0) with **hash keys**. A hash key is a deterministic value computed from business key(s) using a hash function. The same input always produces the same output, enabling parallel loading without sequence coordination.

## Why Hash Keys?

| Problem with Sequences | Hash Key Solution |
|----------------------|-------------------|
| Requires centralized sequence generator | Computed independently by any process |
| Sequential loading (bottleneck) | Fully parallel loading |
| Can't compute in staging area | Pre-computed in staging |
| Different across environments | Same hash in dev, test, prod |
| Lookup required for FK resolution | FK = same hash formula applied to same BK |

## Hash Functions

| Function | Output Size | Collision Risk | Performance | Recommendation |
|----------|------------|----------------|-------------|----------------|
| MD5 | 128 bits (32 hex) | Very low for DW | Fast | Default choice |
| SHA-1 | 160 bits (40 hex) | Lower than MD5 | Slower | Acceptable |
| SHA-256 | 256 bits (64 hex) | Near-zero | Slowest | Overkill for most DW |

**MD5 is the standard** for Data Vault. Cryptographic weakness is irrelevant — this is key generation, not security.

## Three Types of Hashes

### 1. Hub Hash Key

Hash of a single business key (or composite BK):

```sql
-- Single business key
hub_customer_hk = MD5(UPPER(TRIM(COALESCE(customer_id, '-1'))))

-- Composite business key
hub_order_line_hk = MD5(CONCAT(
    COALESCE(UPPER(TRIM(order_id)), '-1'), '||',
    COALESCE(UPPER(TRIM(line_number)), '-1')
))
```

### 2. Link Hash Key

Hash of ALL participating hub hash keys:

```sql
lnk_customer_order_hk = MD5(CONCAT(
    COALESCE(hub_customer_hk, '-1'), '||',
    COALESCE(hub_order_hk, '-1')
))
```

### 3. Hashdiff (Satellite Change Detection)

Hash of ALL descriptive columns in a satellite:

```sql
hashdiff = MD5(CONCAT(
    COALESCE(UPPER(TRIM(first_name)), '^^'), '||',
    COALESCE(UPPER(TRIM(last_name)), '^^'), '||',
    COALESCE(UPPER(TRIM(email)), '^^')
))
```

## Normalization Rules

Apply consistently across all hash computations:

| Rule | Why | Example |
|------|-----|---------|
| `UPPER()` | Case-insensitive matching | `'Smith'` = `'SMITH'` |
| `TRIM()` | Ignore leading/trailing spaces | `' Smith '` = `'Smith'` |
| `COALESCE(val, sentinel)` | NULLs must hash consistently | NULL → `'-1'` or `'^^'` |
| Fixed column order | Same columns must hash identically | Alphabetical or defined order |
| Delimiter between fields | Prevent `'AB' + 'C'` = `'A' + 'BC'` | `'||'` separator |

## Storage Format

```sql
-- BINARY (recommended): Compact, 16 bytes for MD5
hub_customer_hk  BINARY(16)

-- VARCHAR: Human-readable, 32 chars for MD5
hub_customer_hk  VARCHAR(32)

-- Conversion
MD5_BINARY(input)           -- Returns BINARY directly
MD5(input)                  -- Returns hex VARCHAR (platform-dependent)
```

**BINARY is preferred** for storage efficiency (~50% less than VARCHAR hex).

## Platform-Specific Syntax

```sql
-- Snowflake
MD5(CONCAT(COALESCE(UPPER(TRIM(col1)), '-1'), '||', ...))
-- or
MD5_BINARY(...)  -- returns BINARY directly

-- BigQuery
TO_HEX(MD5(CONCAT(COALESCE(UPPER(TRIM(col1)), '-1'), '||', ...)))

-- Databricks / Spark SQL
MD5(CONCAT_WS('||', COALESCE(UPPER(TRIM(col1)), '-1'), ...))
```

## Best Practices

- Use the **same hash function** across the entire vault (don't mix MD5 and SHA)
- Define normalization rules once in a **macro or UDF** — never inline
- Store hash computation logic in **version control**
- Use `BINARY` storage where the platform supports it
- Document the **column order** used in composite hashes
- Test that re-computing the hash from BKs matches stored hash keys

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Inconsistent UPPER/TRIM | Same BK produces different hashes | Always normalize |
| No NULL handling | NULL concatenation = NULL in some DBs | COALESCE with sentinel |
| No delimiter | `'AB'+'C'` = `'A'+'BC'` | Use `'||'` separator |
| Mixing hash functions | Can't join between entities | Standardize on one |
| VARCHAR storage for large tables | Wasted storage | Use BINARY(16) |

## See Also

- [hubs.md](hubs.md) — Hub hash key usage
- [links.md](links.md) — Link hash key composition
- [satellites.md](satellites.md) — Hashdiff for change detection
