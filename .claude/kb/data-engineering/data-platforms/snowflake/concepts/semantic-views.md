# Semantic Views

> **Purpose**: Schema-level objects that define table semantics for Cortex Analyst natural language queries
> **Confidence**: 0.90
> **MCP Validated**: 2026-04-14

## Overview

Semantic Views are native Snowflake objects (GA Oct 2025) that define table structure, column meanings, metrics, relationships, and verified queries for Cortex Analyst. They replace the legacy YAML-on-stage approach with full RBAC integration and Snowsight wizard support.

## The Pattern

```sql
-- Create via DDL (or Snowsight wizard)
USE ROLE TRANSFORMER_ROLE;
CREATE OR REPLACE SEMANTIC VIEW AD_ANALYTICS.GOLD.MY_ANALYST
  AS $$
  name: my_analyst
  description: "Sales and product analytics"

  tables:
    - name: sales
      base_table:
        database: AD_ANALYTICS
        schema: GOLD
        table: F_SALES

      dimensions:
        - name: order_status
          expr: STATUS
          data_type: VARCHAR
          description: "COMPLETE, PROCESSING, UNVERIFIED, CANCELED"
          is_enum: true
          synonyms: ["status"]

      time_dimensions:
        - name: order_date
          expr: CREATED_AT
          data_type: TIMESTAMP_NTZ
          description: "Order date in EDT"
          synonyms: ["date", "sale date"]

      facts:
        - name: revenue
          expr: ROW_TOTAL
          data_type: NUMBER
          description: "Line item revenue in USD"

      metrics:
        - name: total_revenue
          expr: SUM(ROW_TOTAL)
          description: "Sum of all revenue"
          synonyms: ["gross sales", "total sales"]

      filters:
        - name: completed_orders
          description: "Standard order statuses"
          expr: "STATUS IN ('COMPLETE','PROCESSING','UNVERIFIED')"

  relationships:
    - name: sales_to_products
      left_table: sales
      right_table: products
      relationship_columns:
        - left_column: PRODUCT_ID
          right_column: PRODUCT_ID

  verified_queries:
    - name: revenue_today
      question: "What is total revenue today?"
      sql: "SELECT SUM(ROW_TOTAL) FROM AD_ANALYTICS.GOLD.F_SALES WHERE CREATED_AT::DATE = CURRENT_DATE()"
      use_as_onboarding_question: true
  $$;
```

## YAML Sections

| Section | Purpose | Required |
|---|---|---|
| `tables[].dimensions` | Categorical/text columns (WHERE, GROUP BY) | Yes |
| `tables[].time_dimensions` | Date/timestamp columns for time-based queries | Yes (for time queries) |
| `tables[].facts` | Numeric row-level values (used in aggregations) | Yes |
| `tables[].metrics` | Pre-defined aggregation expressions | Recommended |
| `tables[].filters` | Named WHERE clauses Analyst can reference | Recommended |
| `relationships` | Join paths between tables | Yes (for multi-table) |
| `verified_queries` | Gold-standard SQL examples for common questions | Critical |

## Key Properties

- **`is_enum: true`** — tells Analyst to match exact values (essential for status, category columns)
- **`synonyms`** — alternative names users might say ("brand" for manufacturer)
- **`unique: true`** — marks primary key columns for correct aggregation
- **`use_as_onboarding_question`** — surfaces verified query as a suggested starter question

## Semantic View vs YAML on Stage

| Feature | Semantic View | YAML on Stage |
|---|---|---|
| RBAC | Full (GRANT USAGE) | Stage-level only |
| Relationship inference | Auto-inferred | Must specify `relationship_type` |
| Creation UI | Snowsight wizard + SQL | Manual YAML editing |
| API parameter | `semantic_view` | `semantic_model_file` |
| Git version control | Extract via `GET_DDL()` | Native YAML in repo |
| Recommendation | New implementations | Legacy / backward compat |

## RBAC Pattern

```sql
USE ROLE ACCOUNTADMIN;
-- Owner creates the view
GRANT CREATE SEMANTIC VIEW ON SCHEMA AD_ANALYTICS.GOLD TO ROLE TRANSFORMER_ROLE;
-- Viewers can query via Cortex Analyst
GRANT USAGE ON SEMANTIC VIEW AD_ANALYTICS.GOLD.MY_ANALYST TO ROLE DASHBOARD_VIEWER_ROLE;
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Putting aggregations in `facts` | Facts are row-level; aggregations go in `metrics` |
| Missing `time_dimensions` | Required for "today", "this month" queries to work |
| No `verified_queries` | Add 10-15 golden questions — biggest accuracy lever |
| Forgetting `is_enum` on categorical columns | Analyst will fuzzy-match instead of exact-match |
| Over 10 tables in first iteration | Start small (5-6), expand after accuracy is validated |
