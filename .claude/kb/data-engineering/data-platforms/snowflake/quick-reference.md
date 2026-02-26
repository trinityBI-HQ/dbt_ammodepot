# Snowflake Quick Reference

> **MCP Validated**: 2026-02-25
> Fast lookup tables. For code examples, see linked files.

## Warehouse Sizes

| Size | Standard Cr/Hr | Interactive Cr/Hr | Interactive Dataset |
|------|---------------|-------------------|---------------------|
| X-Small | 1 | ~0.6 | < 500 GB |
| Small | 2 | ~1.2 | 500 GB-1 TB |
| Medium | 4 | ~2.4 | 1-2 TB |
| Large | 8 | ~4.8 | 2-4 TB |
| X-Large+ | 16+ | ~9.6+ | 4 TB+ |

## Data Loading Methods

| Method | Latency | Use Case | Cost Model |
|--------|---------|----------|------------|
| COPY INTO | Minutes | Batch ETL, migrations | Warehouse compute |
| Snowpipe | Seconds | Streaming, continuous | Serverless per-file |
| External Tables | None | Query-in-place | Query-time only |
| Openflow | Sec-min | Any source, unstructured | vCPU or credits |

## Key SQL Syntax

| Operation | Syntax |
|-----------|--------|
| Create Interactive WH | `CREATE INTERACTIVE WAREHOUSE iwh TABLES (t1) WAREHOUSE_SIZE='XSMALL'` |
| Create Interactive Table | `CREATE INTERACTIVE TABLE t CLUSTER BY (c1) AS SELECT ...` |
| Dynamic Interactive Table | `... CLUSTER BY (c1) TARGET_LAG='5 min' WAREHOUSE=wh AS ...` |
| Load Data | `COPY INTO table FROM @stage FILE_FORMAT=(TYPE='CSV')` |
| Query JSON | `SELECT col:key::string FROM table` |
| Flatten Array | `SELECT f.value FROM table, LATERAL FLATTEN(col) f` |

## Cortex AI Functions (GA Nov 2025)

| Function | Purpose |
|----------|---------|
| `AI_CLASSIFY` | Categorize into labels (text/image) |
| `AI_EXTRACT` | Extract structured data (text/image) |
| `AI_SENTIMENT` | Sentiment analysis (text) |
| `AI_EMBED` | Generate vector embeddings (text/image) |
| `AI_SIMILARITY` | Compare embeddings (vectors) |
| `AI_TRANSLATE` | Language translation (text) |
| `AI_TRANSCRIBE` | Audio/video to text |
| `AI_REDACT` | PII detection and redaction (text) |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Batch loads (hourly+) | COPY INTO |
| Near real-time (<1 min) | Snowpipe |
| Sub-second point lookups | Interactive Tables + Interactive WH |
| Pre-computed aggregates | Materialized Views |
| Declarative pipelines | Dynamic Tables |
| Natural language queries | Intelligence + Semantic Views |
| Any-source integration | Openflow (BYOC or SPCS) |
| AI-assisted development | Cortex Code (CLI or Snowsight) |

## Feature Timeline (2025-2026)

| Feature | Status | Date |
|---------|--------|------|
| Openflow BYOC | GA | May 2025 |
| Semantic Views | GA | Oct 2025 |
| Cortex AI Functions | GA | Nov 2025 |
| Interactive Tables + WH | GA | Dec 2025 |
| Gen2 Warehouses (2.1x faster) | GA | 2025 |
| Adaptive Compute | Preview | 2025 |
| Cortex Code CLI | GA | Feb 2026 |
| Cortex Code Snowsight | Preview | Feb 2026 |

## Common Pitfalls

| Avoid | Do Instead |
|-------|------------|
| X-Large for small queries | Right-size warehouse to workload |
| Many small files | Batch files to 100-250 MB |
| VARIANT without casting | Extract to typed columns |
| UPDATE on Interactive Tables | Use INSERT OVERWRITE or TARGET_LAG |
| Standard tables on Interactive WH | Interactive WH only queries Interactive Tables |
| Long-lived creds for Openflow | Use Snowflake Managed Tokens |

## Related

| Topic | Path |
|-------|------|
| Interactive Analytics | `concepts/interactive-tables.md` |
| AI Development | `concepts/cortex-code.md` |
| Data Integration | `concepts/openflow.md` |
| Full Index | `index.md` |
