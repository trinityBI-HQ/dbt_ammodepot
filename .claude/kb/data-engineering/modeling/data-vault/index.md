# Data Vault 2.0 Knowledge Base

> **Purpose**: Data modeling methodology for enterprise data warehouses — auditable, scalable, insert-only
> **Author**: Dan Linstedt (formalized ~2013, DV 1.0 from 2000)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/hubs.md](concepts/hubs.md) | Business keys — the core entities |
| [concepts/links.md](concepts/links.md) | Relationships between hubs |
| [concepts/satellites.md](concepts/satellites.md) | Descriptive context and history |
| [concepts/hash-keys.md](concepts/hash-keys.md) | Hash-based keys for parallel loading |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/loading-patterns.md](patterns/loading-patterns.md) | Hub/Link/Satellite loading strategies |
| [patterns/business-vault.md](patterns/business-vault.md) | Business rules, PIT tables, Bridge tables |
| [patterns/dbt-integration.md](patterns/dbt-integration.md) | AutomateDV and DataVault4dbt patterns |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

Data Vault 2.0 is a **three-pillar methodology**: Modeling + Architecture + Methodology.

| Concept | Description |
|---------|-------------|
| **Hub** | Business key entity (customer, order, product) — insert-only |
| **Link** | Relationship/transaction between two+ hubs — insert-only |
| **Satellite** | Descriptive attributes with temporal history — insert-only |
| **Hash Key** | MD5/SHA-256 hash of business key(s) for parallel loading |
| **Raw Vault** | System of record — zero business rules, full auditability |
| **Business Vault** | Derived data with business rules applied (PIT, Bridge, computed Sats) |

### Core Principle: Insert-Only

Data Vault **never updates or deletes** rows. All changes are captured as new satellite records with load timestamps. This guarantees full audit trail and bitemporal history.

---

## Architecture

```text
Source Systems → Staging Area → Raw Vault → Business Vault → Data Marts
                                  ↓              ↓              ↓
                              Hubs/Links/    PIT/Bridge/     Star Schema
                              Satellites     Computed Sats   (presentation)
```

Data Vault serves as the **integration layer**. Star Schema marts serve as the **presentation layer**. They are complementary, not competing.

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/hubs.md, concepts/links.md, concepts/satellites.md |
| **Intermediate** | concepts/hash-keys.md, patterns/loading-patterns.md |
| **Advanced** | patterns/business-vault.md, patterns/dbt-integration.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| dbt-expert | patterns/dbt-integration.md | Implement Data Vault with dbt |
| medallion-architect | patterns/business-vault.md | Design integration + presentation layers |
| snowflake-expert | patterns/loading-patterns.md | Snowflake-specific DV loading |

---

## When to Use Data Vault

| Scenario | Data Vault | Star Schema | 3NF |
|----------|:----------:|:-----------:|:---:|
| Multiple source systems | Best | Poor | Good |
| Full audit trail required | Best | Poor | Good |
| Agile/iterative development | Best | Poor | Fair |
| Direct BI querying | Poor | Best | Fair |
| Regulatory compliance | Best | Poor | Good |
| Simple analytics warehouse | Overkill | Best | Fair |
| Single source system | Overkill | Best | Good |

**Rule of thumb**: Use Data Vault as integration layer + Star Schema marts for presentation.

---

## Tooling Updates

### AutomateDV v0.11.0 (May 2025)

- Composite primary key consistency improvements
- Incremental load consistency enhancements
- PIT and Bridge table generation improvements
- See [patterns/dbt-integration.md](patterns/dbt-integration.md) for usage details
