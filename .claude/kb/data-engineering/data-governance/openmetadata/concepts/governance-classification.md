# Governance & Classification

> **Purpose**: Tags, tiers, glossaries, policies, roles, and teams in OpenMetadata
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

OpenMetadata provides a comprehensive governance framework including glossaries for business terminology, classifications for tagging and categorizing data, tiers for importance ranking, and policies with RBAC for access control. Version 1.6 introduced automated governance workflows and data certification.

## Glossaries

Glossaries organize business terminology in hierarchical structures with controlled definitions:

```text
Business Glossary
  +-- Customer
  |     +-- Active Customer (definition, synonyms, related terms)
  |     +-- Churned Customer
  |     +-- Customer Lifetime Value (CLV)
  +-- Revenue
        +-- MRR (Monthly Recurring Revenue)
        +-- ARR (Annual Recurring Revenue)
```

Key properties of glossary terms:
- **Definition**: Rich text explanation
- **Synonyms**: Alternative names for discoverability
- **Related Terms**: Associative links between concepts
- **Reviewers**: Users who approve term changes
- **Tags**: Classification tags attached to terms
- **Assets**: Data assets linked to the glossary term

## Classifications & Tags

Classifications group related tags for systematic data categorization:

| Classification | Tags | Purpose |
|---------------|------|---------|
| PII | Sensitive, NonSensitive | Personal data identification |
| PersonalData | Personal, SpecialCategory | GDPR compliance |
| Tier | Tier1, Tier2, Tier3, Tier4, Tier5 | Data importance ranking |
| Confidentiality | Public, Internal, Restricted | Access levels |

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata

client = OpenMetadata(config)

# Add a tag to a table column
client.patch_tag(
    entity=Table,
    source=table_entity,
    tag_label=TagLabel(
        tagFQN="PII.Sensitive",
        source="Classification"
    ),
    column_name="email"
)
```

## Tiers

Tiers define data importance levels to prioritize governance efforts:

| Tier | Meaning | Governance Level |
|------|---------|-----------------|
| Tier 1 | Mission-critical, regulatory | Highest: strict ownership, quality tests, SLAs |
| Tier 2 | Important business data | High: ownership required, quality recommended |
| Tier 3 | Operational data | Medium: ownership recommended |
| Tier 4 | Exploratory/dev data | Low: minimal governance |
| Tier 5 | Temporary/test data | None: can be deleted |

## Roles & Policies

OpenMetadata implements RBAC with roles and policies:

| Component | Purpose |
|-----------|---------|
| **Roles** | Named permission sets (DataSteward, DataConsumer, Admin) |
| **Policies** | Rules defining allowed/denied operations |
| **Teams** | Hierarchical groups of users |
| **Personas** | UI experience customization per role |

### Built-in Roles

| Role | Permissions |
|------|------------|
| Admin | Full platform access |
| DataSteward | Manage governance, glossaries, tags, ownership |
| DataConsumer | Read access, follow assets, add descriptions |
| DataQuality | Manage test suites, run profiler |

## Automated Governance (v1.6+)

- **Glossary Approval Workflow**: Require reviewer approval for term changes
- **Data Certification**: Automate Bronze/Silver/Gold certification based on rules
- **Search RBAC**: Users only see assets they have permission to access
- **Auto-classification**: Automated PII detection and tag suggestion

## Ownership Model

Ownership can be assigned at any entity level:

- **User ownership**: Individual accountability
- **Team ownership**: Shared team responsibility
- Every entity should have an owner for accountability
- Ownership is inherited down the hierarchy (database -> schema -> table)

## Related

- [Data Assets](../concepts/data-assets.md)
- [Data Quality](../concepts/data-quality.md)
- [Governance Workflows](../patterns/governance-workflows.md)
