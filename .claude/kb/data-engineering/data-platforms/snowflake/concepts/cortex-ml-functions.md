# Cortex ML Functions

> **Purpose**: Built-in ML functions for forecasting, anomaly detection, and classification without external models
> **Confidence**: 0.85
> **MCP Validated**: 2026-04-14

## Overview

Snowflake Cortex ML functions provide pre-built machine learning capabilities directly in SQL. No model training infrastructure, no external APIs — runs on warehouse compute. Key functions: FORECAST (time-series prediction), ANOMALY_DETECTION (statistical outliers), and Cortex LLM functions (COMPLETE, SUMMARIZE, EXTRACT_ANSWER).

## FORECAST (Time-Series Prediction)

```sql
-- Create a forecast model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST sales_forecast(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'daily_sales_view'),
    TIMESTAMP_COLNAME => 'sale_date',
    TARGET_COLNAME => 'total_revenue'
);

-- Generate predictions (next 30 days)
CALL sales_forecast!FORECAST(FORECASTING_PERIODS => 30);

-- With series (forecast per category)
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST category_forecast(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'daily_sales_by_category'),
    SERIES_COLNAME => 'category',
    TIMESTAMP_COLNAME => 'sale_date',
    TARGET_COLNAME => 'total_revenue'
);
```

**Requirements**: Minimum 2 complete seasonal cycles of data. Daily data needs ~730 rows; weekly needs ~104.

**Output columns**: `TS` (timestamp), `FORECAST` (predicted value), `LOWER_BOUND`, `UPPER_BOUND` (confidence interval).

## ANOMALY_DETECTION (Statistical Outliers)

```sql
-- Create anomaly detection model
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION cost_anomalies(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'daily_cost_view'),
    TIMESTAMP_COLNAME => 'cost_date',
    TARGET_COLNAME => 'daily_credits',
    LABEL_COLNAME => ''  -- unsupervised
);

-- Detect anomalies in new data
CALL cost_anomalies!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'recent_costs'),
    TIMESTAMP_COLNAME => 'cost_date',
    TARGET_COLNAME => 'daily_credits'
);
```

**Output columns**: `TS`, `Y` (actual), `FORECAST`, `IS_ANOMALY` (boolean), `PERCENTILE`, `DISTANCE`.

## Cortex LLM Functions

```sql
-- COMPLETE: General LLM generation
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large',
    'Summarize this sales trend: ' || trend_description
) AS summary;

-- SUMMARIZE: Condense long text
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(product_description) AS summary
FROM products;

-- EXTRACT_ANSWER: Question answering over text
SELECT SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
    document_text,
    'What is the return policy?'
) AS answer;

-- SENTIMENT: Score text -1 to 1
SELECT SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS score
FROM reviews;

-- EMBED_TEXT: Generate vector embeddings
SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', product_name) AS embedding
FROM products;
```

## LLM Models Available

| Model | Use Case | Speed |
|---|---|---|
| `mistral-large` | Complex reasoning, analysis | Slower |
| `mistral-7b` | Simple generation, classification | Fast |
| `llama3.1-70b` | General purpose | Medium |
| `llama3.1-8b` | Simple tasks, high throughput | Fast |

## Pricing

| Function | Billing |
|---|---|
| FORECAST / ANOMALY_DETECTION | Warehouse credits (compute time) |
| COMPLETE / SUMMARIZE | Cortex LLM credits (per token, model-dependent) |
| SENTIMENT / EMBED_TEXT | Cortex AI credits (per call) |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Too little training data for FORECAST | Need 2+ full seasonal cycles minimum |
| Using COMPLETE for structured queries | Use Cortex Analyst for text-to-SQL instead |
| Running LLM functions on large tables without LIMIT | Start with samples; LLM calls are per-row |
| Not specifying SERIES_COLNAME for multi-series forecast | Each series gets its own model; omitting gives one global model |
| Expecting real-time FORECAST results | Model training is batch; call FORECAST for predictions after training |
