# BigQuery

> **Purpose**: Serverless data warehouse with streaming, AI functions, and real-time analytics
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

BigQuery is a fully managed, serverless data warehouse supporting streaming inserts, AI-powered SQL functions, continuous queries, and vector search. The **BigQuery AI** umbrella (Nov 2025) introduces managed functions for inference directly from SQL.

## New Features (2025-2026)

| Feature | Status | Description |
|---------|--------|-------------|
| AI.GENERATE / AI.GENERATE_TABLE | GA (Feb 2026) | LLM inference from SQL queries |
| AI.IF, AI.CLASSIFY, AI.SCORE | GA | Classification and scoring via SQL |
| Continuous queries | GA (2025) | Real-time SQL, export to Pub/Sub/Bigtable/Spanner |
| Vector search | Production-ready | Native `VECTOR_SEARCH` function |
| Global queries | Preview (Feb 2026) | Query datasets across regions |
| Dataset insights | Preview (Feb 2026) | Auto-generated relationship graphs |
| HuggingFace/Vertex Model Garden | Preview (Jan 2026) | Managed inference endpoints |
| BigQuery MCP server | Auto-enabled March 17, 2026 | MCP integration for AI tools |

## The Pattern

```python
from google.cloud import bigquery
from datetime import datetime

def insert_invoice_data(project_id: str, dataset_id: str, table_id: str, invoice: dict):
    """Stream invoice data to BigQuery."""
    client = bigquery.Client(project=project_id)
    table_ref = f"{project_id}.{dataset_id}.{table_id}"

    row = {
        "invoice_id": invoice["invoice_id"],
        "vendor_name": invoice["vendor_name"],
        "invoice_date": invoice["invoice_date"],
        "total_amount": float(invoice["total_amount"]),
        "line_items": invoice.get("line_items", []),
        "processed_at": datetime.utcnow().isoformat(),
        "source_file": invoice["source_file"]
    }

    errors = client.insert_rows_json(table_ref, [row])
    if errors:
        raise RuntimeError(f"BigQuery insert failed: {errors}")
    return row["invoice_id"]
```

## BigQuery AI Functions

```sql
-- AI.GENERATE: LLM inference from SQL (GA Feb 2026)
SELECT invoice_id, AI.GENERATE(
  MODEL `project.dataset.gemini_model`,
  CONCAT('Classify this invoice: ', vendor_name, ' ', CAST(total_amount AS STRING))
) AS classification
FROM `project.invoices.extracted_data`
WHERE invoice_date = CURRENT_DATE();

-- Continuous query: Real-time export to Pub/Sub (GA 2025)
CREATE CONTINUOUS QUERY invoice_alerts AS
SELECT invoice_id, total_amount
FROM `project.invoices.extracted_data`
WHERE total_amount > 10000
EXPORT DATA OPTIONS(format='CLOUD_PUBSUB', topic='high-value-invoices');
```

## Partitioning Strategy

| Strategy | Use Case | Invoice Pipeline |
|----------|----------|------------------|
| **Time-unit (DATE)** | Query by date range | Partition by `invoice_date` |
| Ingestion time | When date unknown | Fallback option |
| Integer range | ID-based queries | Not recommended |

## Common Mistakes

### Wrong
```python
# No error handling, no deduplication logic
client.insert_rows_json(table, [row])
```

### Correct
```python
def insert_with_dedup(client, table_ref: str, row: dict, insert_id: str):
    """Insert with deduplication via insertId."""
    errors = client.insert_rows_json(table_ref, [row], row_ids=[insert_id])
    if errors:
        for error in errors:
            if "already exists" not in str(error):
                raise RuntimeError(f"Insert failed: {error}")
    return True
```

## Streaming Constraints

| Constraint | Value | Mitigation |
|------------|-------|------------|
| Past partition limit | 31 days | Buffer old data, batch load |
| Future partition limit | 16 days | Validate dates before insert |
| Dedup window | Minutes | Use unique insertId |
| Max row size | 10 MB | Validate payload size |

## Query Best Practices

```sql
-- Good: Specific columns, partition filter
SELECT invoice_id, vendor_name, total_amount
FROM `project.invoices.extracted_data`
WHERE invoice_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND vendor_name = 'Restaurant ABC';

-- Bad: SELECT *, no partition filter
SELECT * FROM `project.invoices.extracted_data`;
```

## Related

- [Event-Driven Pipeline](../patterns/event-driven-pipeline.md)
- [Cloud Run](../concepts/cloud-run.md)
- [IAM](../concepts/iam.md)
