# Data Contract Fundamentals

> **Purpose**: Core definition, components, and value proposition of data contracts
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A data contract is a formal, versioned agreement between a data producer and its consumers that defines the schema, quality expectations, SLAs, and ownership of a dataset. Data contracts shift data quality left — catching issues at the source rather than downstream — and establish clear accountability for data reliability.

## Why Data Contracts Matter

Without contracts, data pipelines suffer from:
- **Silent schema changes** that break downstream models
- **No ownership** — nobody is accountable when data quality degrades
- **Reactive firefighting** instead of proactive prevention
- **Tribal knowledge** about what fields mean and how fresh data should be

Data contracts solve this by making expectations **explicit, versioned, and enforceable**.

## Core Components

### 1. Schema Definition
The structural specification: field names, data types, nullability, constraints.

```yaml
schema:
  - name: order_id
    type: string
    required: true
    unique: true
    description: "Unique order identifier (UUID v4)"
  - name: total_amount
    type: decimal
    required: true
    constraints:
      minimum: 0
```

### 2. Quality Rules
Expectations beyond schema — statistical checks, business rules, referential integrity.

```yaml
quality:
  - rule: row_count > 0
    description: "Dataset must not be empty"
  - rule: null_percentage(email) < 5
    description: "Email nulls under 5%"
```

### 3. Service-Level Agreements (SLAs)
Guarantees on freshness, availability, and latency.

```yaml
sla:
  freshness: 1h          # Data no older than 1 hour
  availability: 99.9%    # Uptime guarantee
  latency: 5min          # Max processing delay
```

### 4. Ownership
Clear accountability — who produces the data, who to contact on issues.

```yaml
owner:
  team: payments-platform
  contact: payments-data@company.com
  oncall: "#payments-oncall"
```

### 5. Semantics
Business definitions and classifications (PII, sensitivity levels).

```yaml
semantics:
  domain: finance
  classification: confidential
  tags: [PII, GDPR]
```

## Contract Lifecycle

1. **Define** — Producer and consumers agree on contract terms
2. **Publish** — Contract is versioned and stored in a registry
3. **Enforce** — Automated checks run in CI/CD and at runtime
4. **Evolve** — Changes go through versioning and review process
5. **Deprecate** — Old versions sunset with migration period

## Data Contracts vs. Schema Validation

| Aspect | Schema Validation | Data Contract |
|--------|------------------|---------------|
| Scope | Structure only | Structure + quality + SLAs + ownership |
| Timing | Runtime | Design-time + runtime |
| Accountability | None | Producer owns, consumers depend |
| Versioning | Implicit | Explicit semantic versioning |
| Enforcement | Technical | Technical + organizational |

## Related

- [Schema Definition](schema-definition.md)
- [Ownership and SLAs](ownership-and-slas.md)
- [ODCS Specification](../patterns/odcs-specification.md)
