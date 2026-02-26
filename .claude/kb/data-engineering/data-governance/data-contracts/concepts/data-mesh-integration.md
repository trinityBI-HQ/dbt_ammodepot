# Data Contracts in Data Mesh

> **Purpose**: How data contracts enable domain-oriented data ownership in data mesh architectures
> **Confidence**: 0.90
> **MCP Validated**: 2026-02-19

## Overview

Data mesh decentralizes data ownership to domain teams, treating data as a product. Data contracts are the interface layer that makes this work — each domain publishes contracts for its data products, enabling autonomous teams to collaborate without tight coupling.

## Data Mesh Principles and Contracts

| Principle | How Contracts Support It |
|-----------|-------------------------|
| **Domain ownership** | Each domain owns and publishes contracts for its data |
| **Data as a product** | Contracts define the product interface (schema, SLAs, quality) |
| **Self-serve platform** | Contract registry enables discovery and onboarding |
| **Federated governance** | Shared contract standards across autonomous domains |

## Domain-Oriented Contracts

### Contract Per Data Product

Each domain team publishes one contract per data product:

```yaml
dataContractSpecification: 0.9.3
id: urn:datacontract:payments:transactions
info:
  title: Payment Transactions
  version: 1.2.0
  owner: payments-domain
  description: "All completed payment transactions"

# Domain defines its interface
schema:
  - name: transaction_id
    logicalType: string
    required: true
    unique: true
  - name: amount
    logicalType: decimal
    required: true
  - name: currency
    logicalType: string
    required: true
    enum: [USD, EUR, GBP]
  - name: status
    logicalType: string
    required: true
    enum: [completed, refunded]

sla:
  freshness: 15min
  availability: 99.9%

quality:
  - rule: row_count > 0
  - rule: "null_percentage(amount) == 0"
```

### Cross-Domain Dependencies

```
┌─────────────┐    contract    ┌──────────────┐
│  Payments    │──────────────→│  Analytics    │
│  Domain      │               │  Domain       │
│              │    contract    │              │
│  transactions├──────────────→│  revenue     │
│  refunds     │               │  dashboards  │
└─────────────┘               └──────────────┘
       │                              │
       │         contract             │
       └──────────────────────→┌──────┴───────┐
                               │  Finance     │
                               │  Domain      │
                               │  reporting   │
                               └──────────────┘
```

## Consumer-Driven Contract Design

In data mesh, consumers drive contract requirements:

1. **Consumer requests** — Analytics team needs `payment_method` field
2. **Producer evaluates** — Payments team assesses feasibility
3. **Contract updated** — New field added as MINOR version bump
4. **Published** — Updated contract in central registry

```yaml
# Consumer expectation file
consumer:
  team: analytics-domain
  contact: analytics@company.com

expectations:
  dataset: urn:datacontract:payments:transactions
  fields_needed:
    - transaction_id
    - amount
    - currency
    - payment_method  # NEW: consumer request
  freshness: 1h
  quality:
    - "completeness(transaction_id) == 100%"
```

## Contract Registry

A central registry enables discovery across domains:

| Feature | Purpose |
|---------|---------|
| **Search** | Find data products by domain, tag, or keyword |
| **Dependency graph** | Visualize producer-consumer relationships |
| **Compatibility check** | Validate changes against consumer expectations |
| **Lineage** | Trace data from source domain to consumers |
| **Health dashboard** | Monitor SLA compliance across domains |

## Federated Governance Standards

Domains are autonomous but follow shared contract standards:

```yaml
# Organization-wide contract template
governance:
  required_fields:
    - owner
    - version
    - sla.freshness
    - sla.availability
  naming_convention: "urn:datacontract:{domain}:{product}"
  versioning: semantic
  review_required: true
  classification_required: true  # PII, confidential, public
```

## Related

- [Fundamentals](fundamentals.md)
- [Ownership and SLAs](ownership-and-slas.md)
- [Pipeline Enforcement](../patterns/pipeline-enforcement.md)
