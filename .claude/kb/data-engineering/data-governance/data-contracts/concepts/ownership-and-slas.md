# Ownership and SLAs

> **Purpose**: Producer/consumer roles, SLA terms, and accountability models
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Data contracts establish clear ownership and service-level expectations. The producer owns the data and is accountable for its quality, while consumers register their dependencies and expectations. SLAs formalize what "reliable" means in measurable terms.

## Ownership Model

### Producer Responsibilities
- Define and publish the contract
- Ensure data conforms to the schema
- Meet SLA commitments (freshness, availability)
- Communicate breaking changes before deploying
- Maintain backward compatibility within major versions

### Consumer Responsibilities
- Register as a dependent on the contract
- Communicate new requirements through contract requests
- Handle schema evolution gracefully (new optional fields)
- Report contract violations promptly

### Ownership YAML Example

```yaml
team:
  name: payments-platform
  owner: jane.doe@company.com
  slack: "#payments-data"
  oncall: "https://pagerduty.com/payments"

roles:
  - username: jane.doe
    role: Data Owner
    comment: "Accountable for data quality"
  - username: bob.smith
    role: Data Steward
    comment: "Day-to-day contract management"
```

## SLA Components

### Freshness
How recent the data must be when consumed.

```yaml
sla:
  freshness:
    value: 1
    unit: hour
    description: "Data must be no older than 1 hour"
```

### Availability
Uptime guarantee for the dataset or API.

```yaml
sla:
  availability:
    percentage: 99.9
    measurement_period: monthly
    description: "Dataset available 99.9% of the time"
```

### Completeness
Expected data completeness guarantees.

```yaml
sla:
  completeness:
    percentage: 99.5
    description: "At least 99.5% of expected records present"
```

### Latency
Maximum acceptable processing delay.

```yaml
sla:
  latency:
    value: 5
    unit: minutes
    description: "End-to-end processing under 5 minutes"
```

## SLA Tiers

| Tier | Freshness | Availability | Use Case |
|------|-----------|-------------|----------|
| **Critical** | < 5 min | 99.99% | Real-time dashboards, fraud detection |
| **High** | < 1 hour | 99.9% | Operational reporting, analytics |
| **Standard** | < 24 hours | 99.5% | Batch analytics, ML training |
| **Best-effort** | < 7 days | 95% | Historical analysis, experimentation |

## Accountability Framework

### Violation Handling

```yaml
support:
  - channel: "#payments-data-issues"
    type: slack
  - channel: "data-issues@company.com"
    type: email

escalation:
  - level: 1
    contact: data-steward@company.com
    response_time: 1h
  - level: 2
    contact: data-owner@company.com
    response_time: 4h
  - level: 3
    contact: engineering-director@company.com
    response_time: 24h
```

### Monitoring Checklist

- Automated freshness checks on schedule
- Schema validation on every pipeline run
- Quality rule execution with alerting on failures
- SLA compliance dashboards (daily/weekly/monthly)
- Consumer impact analysis before breaking changes

## Common Mistakes

### Wrong
- SLAs defined but never measured or enforced
- Owner field points to a generic team alias nobody monitors
- No escalation path for contract violations

### Correct
- SLAs tied to automated monitoring and alerting
- Named individuals with clear on-call rotations
- Escalation matrix with defined response times

## Related

- [Fundamentals](fundamentals.md)
- [Data Mesh Integration](data-mesh-integration.md)
- [Pipeline Enforcement](../patterns/pipeline-enforcement.md)
