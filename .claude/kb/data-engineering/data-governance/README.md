# Data Governance

> **Category:** Data Engineering > Data Governance
> **Last Updated:** 2026-02-19

## Overview

Data Governance covers the policies, standards, and practices that ensure data is managed as a strategic asset. This includes data catalogs and metadata management, data contracts between producers and consumers, data quality standards, ownership models, and compliance frameworks.

## Technologies

| Technology | Purpose | Status |
|-----------|---------|--------|
| [Data Contracts](data-contracts/) | Schema agreements, SLAs, and quality expectations between data producers and consumers | Active |
| [OpenMetadata](openmetadata/) | Open-source metadata platform for data discovery, lineage, quality, governance, and observability | Active |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Schema agreements between teams | Data Contracts |
| Data catalog and metadata management | OpenMetadata |
| Data discovery and search | OpenMetadata |
| Data lineage visualization | OpenMetadata |
| Built-in data quality testing | OpenMetadata |
| Contract enforcement in pipelines | Data Contracts |
| Business glossary and classification | OpenMetadata |

## When to Use Data Governance Tools

- Multiple teams produce and consume shared datasets
- Breaking schema changes cause downstream pipeline failures
- No clear ownership or accountability for data quality
- Regulatory compliance requires documented data lineage and quality
- Transitioning to a data mesh or domain-oriented architecture
- Need a centralized data catalog for discovery and collaboration

## Related Categories

- **[Data Quality](../data-quality/)** — Runtime validation with Great Expectations
- **[Observability](../observability/)** — Monitoring with Elementary
- **[Modeling](../modeling/)** — Data Vault for auditable integration layers
- **[Transformation](../transformation/)** — dbt for tested, documented transformations
