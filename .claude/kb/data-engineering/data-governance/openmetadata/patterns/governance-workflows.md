# Governance Workflows

> **Purpose**: Setting up classification, ownership, glossaries, approval workflows, and data certification
> **MCP Validated**: 2026-02-19

## When to Use

- Establishing a data governance program with OpenMetadata
- Setting up business glossaries with approval workflows
- Implementing data classification for compliance (PII, GDPR)
- Defining ownership models and accountability structures
- Automating data certification (Bronze/Silver/Gold)

## Glossary Setup Workflow

### Step 1: Create Glossary Structure

```python
from metadata.ingestion.ometa.ometa_api import OpenMetadata
from metadata.generated.schema.api.data.createGlossary import CreateGlossaryRequest
from metadata.generated.schema.api.data.createGlossaryTerm import CreateGlossaryTermRequest

client = OpenMetadata(config)

# Create top-level glossary
glossary = client.create_or_update(
    CreateGlossaryRequest(
        name="BusinessGlossary",
        displayName="Business Glossary",
        description="Organization-wide business terminology",
        reviewers=[{"id": steward_user_id, "type": "user"}],
        owners=[{"id": data_governance_team_id, "type": "team"}],
    )
)

# Create glossary term
client.create_or_update(
    CreateGlossaryTermRequest(
        glossary="BusinessGlossary",
        name="MRR",
        displayName="Monthly Recurring Revenue",
        description="Sum of all active subscription revenue normalized to a monthly period",
        synonyms=["Monthly Revenue", "Recurring Revenue"],
        relatedTerms=[],
        reviewers=[{"id": finance_lead_id, "type": "user"}],
    )
)
```

### Step 2: Link Terms to Data Assets

```python
# Tag a table column with a glossary term
client.patch_tag(
    entity=Table,
    source=table_entity,
    tag_label=TagLabel(
        tagFQN="BusinessGlossary.MRR",
        source="Glossary",
    ),
    column_name="mrr_amount",
)
```

## Classification Workflow

### Step 1: Define Custom Classifications

```python
from metadata.generated.schema.api.classification.createClassification import (
    CreateClassificationRequest,
)
from metadata.generated.schema.api.classification.createTag import CreateTagRequest

# Create classification group
client.create_or_update(
    CreateClassificationRequest(
        name="DataSensitivity",
        description="Data sensitivity levels for compliance",
    )
)

# Create tags within classification
for tag_name, description in [
    ("Public", "Data safe for public access"),
    ("Internal", "Internal use only"),
    ("Confidential", "Restricted access, PII or financial"),
    ("Restricted", "Highly restricted, regulatory compliance"),
]:
    client.create_or_update(
        CreateTagRequest(
            classification="DataSensitivity",
            name=tag_name,
            description=description,
        )
    )
```

### Step 2: Apply Tags to Assets

```python
# Tag an entire table
client.patch_tag(
    entity=Table,
    source=table_entity,
    tag_label=TagLabel(
        tagFQN="DataSensitivity.Confidential",
        source="Classification",
    ),
)

# Tag specific columns as PII
for col in ["email", "phone", "ssn"]:
    client.patch_tag(
        entity=Table,
        source=table_entity,
        tag_label=TagLabel(tagFQN="PII.Sensitive", source="Classification"),
        column_name=col,
    )
```

## Ownership Assignment Pattern

```python
# Assign team ownership to tables matching a pattern
from metadata.generated.schema.entity.data.table import Table

tables = client.list_entities(entity=Table, limit=100)
for table in tables.entities:
    fqn = table.fullyQualifiedName.__root__
    if "marts.finance" in fqn:
        client.patch_owner(
            entity=Table,
            source=table,
            owner=EntityReference(id=finance_team_id, type="team"),
        )
    elif "marts.marketing" in fqn:
        client.patch_owner(
            entity=Table,
            source=table,
            owner=EntityReference(id=marketing_team_id, type="team"),
        )
```

## Data Certification Workflow (v1.6+)

OpenMetadata 1.6 supports automated data certification using governance rules:

| Certification | Criteria | Meaning |
|--------------|----------|---------|
| **Gold** | Owner assigned, description complete, Tier 1/2, quality tests passing | Production-ready, fully governed |
| **Silver** | Owner assigned, description exists, some quality tests | Usable, partially governed |
| **Bronze** | Basic metadata exists | Cataloged, needs governance work |

## Tiering Strategy

```text
Tier 1 (Critical)    --> Revenue tables, customer PII, regulatory data
  Actions: Mandatory owner, daily quality tests, SLA monitoring

Tier 2 (Important)   --> Core business dimensions, aggregated metrics
  Actions: Owner required, weekly quality tests

Tier 3 (Operational) --> Staging tables, intermediate transforms
  Actions: Owner recommended, monthly profiling

Tier 4 (Dev/Test)    --> Development schemas, sandbox data
  Actions: No governance requirements

Tier 5 (Temporary)   --> Temp tables, one-off analysis
  Actions: Auto-cleanup after 30 days
```

## RBAC Policy Example

| Role | Can View | Can Edit | Can Delete | Can Govern |
|------|----------|----------|------------|------------|
| Admin | All | All | All | All |
| DataSteward | All | Descriptions, Tags, Owners | No | Glossary, Tags |
| DataEngineer | All | Own assets | Own assets | No |
| DataAnalyst | Tier 1-3 | Descriptions only | No | No |

## See Also

- [Governance & Classification](../concepts/governance-classification.md)
- [Data Quality](../concepts/data-quality.md)
- [Data Contracts KB](../../data-contracts/)
