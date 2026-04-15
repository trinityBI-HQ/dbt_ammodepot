# Cortex Analyst

> **Purpose**: Text-to-SQL service that translates natural language questions into SQL via semantic models
> **Confidence**: 0.90
> **MCP Validated**: 2026-04-14

## Overview

Cortex Analyst is a serverless REST API that converts natural language questions into SQL queries. It uses a semantic definition (Semantic View or YAML file) to understand table relationships, column meanings, metrics, and business logic. GA since 2024; Semantic View support GA Oct 2025.

## The Pattern

```python
# POST to Cortex Analyst REST API
import requests

url = f"https://{account}.snowflakecomputing.com/api/v2/cortex/analyst/message"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "X-Snowflake-Authorization-Token-Type": "OAUTH"
}
payload = {
    "messages": [
        {"role": "user", "content": [{"type": "text", "text": "Total revenue today?"}]}
    ],
    "semantic_view": "DB.SCHEMA.MY_SEMANTIC_VIEW"  # or semantic_model_file
}
resp = requests.post(url, headers=headers, json=payload, timeout=90)
```

## Authentication (3 Modes)

| Runtime | Token Source | Header |
|---|---|---|
| Local (key-pair) | `conn.rest.token` from snowflake-connector-python | `Snowflake Token="{token}"` |
| SiS warehouse runtime | Same connector pattern | Same |
| SiS container runtime | Read `/snowflake/session/token` file | `Bearer {token}` + `X-Snowflake-Authorization-Token-Type: OAUTH` |

## Response Format

```json
{
  "message": {
    "role": "analyst",
    "content": [
      {"type": "text", "text": "Here are the results..."},
      {"type": "sql", "statement": "SELECT ...", "confidence": {}},
      {"type": "suggestions", "suggestions": ["Follow-up question 1"]}
    ]
  }
}
```

Content block types: `text` (explanation), `sql` (generated query), `suggestions` (follow-ups). When `verified_query_used` is in the confidence object, the LLM matched a pre-validated query.

## Semantic Definition Options

| Option | API Parameter | RBAC | Recommended |
|---|---|---|---|
| Semantic View (DDL object) | `semantic_view` | Full Snowflake RBAC | Yes (new implementations) |
| YAML on stage | `semantic_model_file` | Stage-level only | Legacy |
| Inline YAML string | `semantic_model` | None | Dev/testing only |

## Pricing

- **6.7 credits per 100 messages** (~$0.20/question at $3/credit)
- Only HTTP 200 responses billed; flat rate regardless of token count
- SQL execution billed separately on the warehouse
- Monitor via `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY`

## Limitations

| Limit | Value |
|---|---|
| Semantic model token budget | 32,000 tokens (~128K chars) |
| YAML file size | 1 MB |
| Recommended tables | 5-10 for POC, up to 50+ production |
| Cross-view joins | Not supported |
| Many-to-many relationships | Not directly supported |
| Output | SELECT only (no DML) |
| Result memory | Cannot reference prior query results |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Ambiguous metric names (`revenue`) | Use explicit names (`total_revenue`, `gross_revenue`) |
| Missing `is_enum: true` on categorical columns | Add to prevent fuzzy matching on exact values |
| No verified queries | Add 10-15 golden questions — critical for accuracy |
| Too many tables in semantic model | Start with 5-6, expand after validation |
| Not including synonyms | Users say "brand" not "manufacturer" — add synonyms |
| Missing default filters | Add named filters for standard exclusions (deleted records, test data) |
