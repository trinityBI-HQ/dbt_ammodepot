# VARIANT Data Type

> **Purpose**: Native storage and querying of semi-structured data (JSON, Avro, Parquet) with Cortex AI enrichment
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

VARIANT is Snowflake's native data type for semi-structured data. It stores JSON, Avro, ORC, Parquet, and XML without requiring a predefined schema. VARIANT columns support dot notation and bracket notation for traversal. For analytics, extract frequently queried fields into typed columns for 40-45% faster performance.

## The Pattern

```sql
-- Table with VARIANT column
CREATE TABLE events (
  event_id NUMBER AUTOINCREMENT,
  event_time TIMESTAMP_NTZ,
  payload VARIANT
);

-- Insert JSON data
INSERT INTO events (event_time, payload)
SELECT CURRENT_TIMESTAMP(), PARSE_JSON('{
  "user_id": 123,
  "action": "purchase",
  "items": [{"sku": "A1", "qty": 2}, {"sku": "B2", "qty": 1}],
  "metadata": {"source": "mobile", "version": "2.1"}
}');

-- Query with dot notation (returns VARIANT)
SELECT payload:user_id, payload:action FROM events;

-- Cast to typed columns
SELECT
  payload:user_id::NUMBER as user_id,
  payload:action::STRING as action,
  payload:metadata.source::STRING as source
FROM events;

-- Access array elements
SELECT payload:items[0]:sku::STRING as first_sku FROM events;
```

## Quick Reference

| Syntax | Purpose | Returns |
|--------|---------|---------|
| `col:key` | Access object key | VARIANT |
| `col['key']` | Bracket notation | VARIANT |
| `col:key::TYPE` | Cast to type | Typed value |
| `col:arr[0]` | Array index | VARIANT |
| `PARSE_JSON(str)` | String to VARIANT | VARIANT |
| `TO_JSON(var)` | VARIANT to string | VARCHAR |

| Function | Purpose |
|----------|---------|
| `FLATTEN()` | Expand arrays/objects to rows |
| `ARRAY_SIZE()` | Count array elements |
| `OBJECT_KEYS()` | List object keys |
| `GET_PATH()` | Dynamic path access |

| Cortex AI Function (GA Nov 2025) | Purpose |
|----------------------------------|---------|
| `AI_CLASSIFY(col, labels)` | Classify text/image into categories |
| `AI_EXTRACT(col, keys)` | Extract structured data from text |
| `AI_SENTIMENT(col)` | Sentiment analysis on text |
| `AI_TRANSLATE(col, lang)` | Translate text to target language |
| `AI_EMBED(col)` | Generate vector embeddings |
| `AI_SIMILARITY(v1, v2)` | Compare vector embeddings |
| `AI_TRANSCRIBE(col)` | Audio/video to text |

## Common Mistakes

### Wrong

```sql
-- Querying VARIANT without casting (slow, type issues)
SELECT payload:amount FROM events WHERE payload:amount > 100;

-- Storing dates as strings in JSON
INSERT INTO events (payload) VALUES (PARSE_JSON('{"date": "2024-01-15"}'));
```

### Correct

```sql
-- Cast VARIANT to types for filtering and aggregation
SELECT payload:amount::DECIMAL(10,2) as amount
FROM events
WHERE payload:amount::DECIMAL(10,2) > 100;

-- Extract frequently-queried fields to typed columns
CREATE TABLE events_optimized AS
SELECT
  event_id,
  payload:user_id::NUMBER as user_id,
  payload:action::STRING as action,
  payload  -- Keep full VARIANT for flexibility
FROM events;

-- Enrich semi-structured data with Cortex AI (GA Nov 2025)
SELECT
  payload:review::STRING as review_text,
  AI_SENTIMENT(payload:review::STRING) as sentiment,
  AI_CLASSIFY(payload:review::STRING,
    ['positive', 'negative', 'neutral']) as category,
  AI_EXTRACT(payload:description::STRING,
    ['product_name', 'brand', 'color']) as extracted
FROM events;
```

## Related

- [semi-structured-queries](../patterns/semi-structured-queries.md)
- [tables-views](../concepts/tables-views.md)
