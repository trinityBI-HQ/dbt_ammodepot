# Semi-Structured Data Queries

> **Purpose**: Querying JSON and nested data using FLATTEN, LATERAL, path expressions, and Cortex AI
> **MCP Validated**: 2026-02-19

## When to Use

- Extracting fields from JSON/VARIANT columns
- Expanding nested arrays into rows for analysis
- Working with deeply nested or variable-schema data
- Converting semi-structured data to relational format
- AI-powered enrichment of semi-structured text (classify, extract, sentiment)

## Implementation

```sql
-- Sample data setup
CREATE TABLE events (
  id NUMBER,
  payload VARIANT
);

INSERT INTO events SELECT 1, PARSE_JSON('{
  "user": {"id": 123, "name": "Alice"},
  "items": [
    {"sku": "A1", "qty": 2, "price": 10.00},
    {"sku": "B2", "qty": 1, "price": 25.00}
  ],
  "tags": ["premium", "mobile"]
}');

-- Basic path expressions
SELECT
  payload:user.id::NUMBER AS user_id,
  payload:user.name::STRING AS user_name,
  payload:items[0]:sku::STRING AS first_sku,
  ARRAY_SIZE(payload:items) AS item_count
FROM events;

-- LATERAL FLATTEN for arrays
SELECT
  e.id,
  e.payload:user.id::NUMBER AS user_id,
  f.value:sku::STRING AS sku,
  f.value:qty::NUMBER AS qty,
  f.value:price::DECIMAL(10,2) AS price,
  f.index AS item_index
FROM events e,
LATERAL FLATTEN(input => e.payload:items) f;

-- FLATTEN output columns
SELECT
  f.seq,    -- Unique sequence per input row
  f.key,    -- Object key (NULL for arrays)
  f.path,   -- Path to element
  f.index,  -- Array index (NULL for objects)
  f.value,  -- The flattened value
  f.this    -- Parent element (for recursion)
FROM events,
LATERAL FLATTEN(input => payload:items) f;

-- Multiple nested levels
SELECT
  e.id,
  items.value:sku::STRING AS sku,
  tags.value::STRING AS tag
FROM events e,
LATERAL FLATTEN(input => e.payload:items) items,
LATERAL FLATTEN(input => e.payload:tags) tags;

-- Recursive flatten for deeply nested structures
SELECT
  f.path,
  f.key,
  f.value
FROM events,
LATERAL FLATTEN(input => payload, RECURSIVE => TRUE) f
WHERE TYPEOF(f.value) != 'OBJECT' AND TYPEOF(f.value) != 'ARRAY';
```

## Configuration

| FLATTEN Parameter | Default | Description |
|-------------------|---------|-------------|
| `INPUT` | Required | VARIANT column or expression |
| `PATH` | '' | Path to element to flatten |
| `OUTER` | FALSE | Include rows with NULL/empty arrays |
| `RECURSIVE` | FALSE | Flatten all nested levels |
| `MODE` | 'BOTH' | OBJECT, ARRAY, or BOTH |

## Example Usage

```sql
-- Transform JSON events to relational table
CREATE TABLE orders_flat AS
SELECT
  e.id AS event_id,
  e.payload:order_id::NUMBER AS order_id,
  e.payload:customer.id::NUMBER AS customer_id,
  e.payload:customer.email::STRING AS email,
  f.value:product_id::NUMBER AS product_id,
  f.value:quantity::NUMBER AS quantity,
  f.value:unit_price::DECIMAL(10,2) AS unit_price,
  f.index + 1 AS line_number
FROM events e,
LATERAL FLATTEN(input => e.payload:line_items, OUTER => TRUE) f;

-- Aggregate within flattened data
SELECT
  payload:user.id::NUMBER AS user_id,
  SUM(f.value:price::DECIMAL * f.value:qty::NUMBER) AS total
FROM events,
LATERAL FLATTEN(input => payload:items) f
GROUP BY 1;

-- Handle optional/missing keys with TRY_CAST
SELECT
  payload:user.id::NUMBER AS user_id,
  TRY_CAST(payload:metadata.score AS NUMBER) AS score,
  COALESCE(payload:status::STRING, 'unknown') AS status
FROM events;

-- Cortex AI on semi-structured data (GA Nov 2025)
-- Classify, extract, and analyze text from VARIANT columns
SELECT
  e.id,
  e.payload:review::STRING AS review_text,
  AI_SENTIMENT(e.payload:review::STRING) AS sentiment,
  AI_CLASSIFY(
    e.payload:review::STRING,
    ['bug_report', 'feature_request', 'praise', 'complaint']
  ) AS ticket_type,
  AI_EXTRACT(
    e.payload:description::STRING,
    ['product', 'issue', 'severity']
  ) AS extracted_fields
FROM events e;

-- AI embeddings for semantic search on JSON text fields
SELECT
  id,
  payload:title::STRING AS title,
  AI_EMBED(payload:title::STRING) AS title_embedding
FROM documents;

-- Similarity search using embeddings
SELECT a.id, b.id, AI_SIMILARITY(a.embedding, b.embedding) AS score
FROM docs_embedded a, docs_embedded b
WHERE a.id != b.id AND AI_SIMILARITY(a.embedding, b.embedding) > 0.8;
```

## See Also

- [variant-data](../concepts/variant-data.md)
- [tables-views](../concepts/tables-views.md)
