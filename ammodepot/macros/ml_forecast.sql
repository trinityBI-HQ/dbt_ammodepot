{# ──────────────────────────────────────────────────────────────────────────
   ML Training Macros — run via `dbt run-operation`

   Usage:
     dbt run-operation train_caliber_forecast --profiles-dir . --target prod
     dbt run-operation train_revenue_forecast --profiles-dir . --target prod
     dbt run-operation train_anomaly_models --profiles-dir . --target prod
     dbt run-operation train_all_ml_models --profiles-dir . --target prod
   ────────────────────────────────────────────────────────────────────────── #}


{% macro train_caliber_forecast() %}
  {# Train SNOWFLAKE.ML.FORECAST on daily units by caliber #}
  {% do log("Training caliber forecast model...", info=True) %}

  {# Create forecast history table on first run #}
  {% call statement('create_forecast_history') %}
    CREATE TABLE IF NOT EXISTS AD_ANALYTICS.GOLD.F_FORECAST_HISTORY (
        CALIBER         VARCHAR,
        FORECAST_DATE   DATE,
        PREDICTED_UNITS FLOAT,
        LOWER_BOUND     FLOAT,
        UPPER_BOUND     FLOAT,
        FORECAST_TYPE   VARCHAR,
        TRAINED_AT      TIMESTAMP_NTZ,
        ARCHIVED_AT     TIMESTAMP_NTZ
    )
  {% endcall %}

  {# Archive current caliber predictions before overwriting #}
  {% do log("Archiving current caliber forecast to history...", info=True) %}
  {% call statement('archive_caliber') %}
    INSERT INTO AD_ANALYTICS.GOLD.F_FORECAST_HISTORY
    SELECT
        CALIBER, FORECAST_DATE, PREDICTED_UNITS,
        LOWER_BOUND, UPPER_BOUND, FORECAST_TYPE,
        TRAINED_AT, CURRENT_TIMESTAMP() AS ARCHIVED_AT
    FROM AD_ANALYTICS.GOLD.F_FORECAST
    WHERE FORECAST_TYPE = 'caliber'
  {% endcall %}

  {% call statement('train_caliber') %}
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST AD_ANALYTICS.GOLD.CALIBER_FORECAST(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_BY_CALIBER'),
        SERIES_COLNAME => 'CALIBER',
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'UNITS_SOLD'
    )
  {% endcall %}

  {% do log("Generating 30-day caliber predictions...", info=True) %}

  {% call statement('predict_caliber') %}
    INSERT OVERWRITE INTO AD_ANALYTICS.GOLD.F_FORECAST
    SELECT
        SERIES          AS CALIBER,
        TS              AS FORECAST_DATE,
        FORECAST        AS PREDICTED_UNITS,
        LOWER_BOUND,
        UPPER_BOUND,
        'caliber'       AS FORECAST_TYPE,
        CURRENT_TIMESTAMP() AS TRAINED_AT
    FROM TABLE(AD_ANALYTICS.GOLD.CALIBER_FORECAST!FORECAST(
        FORECASTING_PERIODS => 30
    ))
  {% endcall %}

  {% do log("Caliber forecast complete.", info=True) %}
{% endmacro %}


{% macro train_revenue_forecast() %}
  {# Train SNOWFLAKE.ML.FORECAST on daily total revenue #}
  {% do log("Training revenue forecast model...", info=True) %}

  {% call statement('train_revenue') %}
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST AD_ANALYTICS.GOLD.REVENUE_FORECAST(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.V_DAILY_REVENUE'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'TOTAL_REVENUE'
    )
  {% endcall %}

  {% do log("Generating 30-day revenue predictions...", info=True) %}

  {% call statement('predict_revenue') %}
    INSERT INTO AD_ANALYTICS.GOLD.F_FORECAST
    SELECT
        'REVENUE'       AS CALIBER,
        TS              AS FORECAST_DATE,
        FORECAST        AS PREDICTED_UNITS,
        LOWER_BOUND,
        UPPER_BOUND,
        'revenue'       AS FORECAST_TYPE,
        CURRENT_TIMESTAMP() AS TRAINED_AT
    FROM TABLE(AD_ANALYTICS.GOLD.REVENUE_FORECAST!FORECAST(
        FORECASTING_PERIODS => 30
    ))
  {% endcall %}

  {% do log("Revenue forecast complete.", info=True) %}
{% endmacro %}


{% macro train_anomaly_models() %}
  {# Train SNOWFLAKE.ML.ANOMALY_DETECTION on daily sales metrics.
     Training data: all data BEFORE last 30 days (baseline).
     Detection data: last 30 days (what we check for anomalies).
     These must NOT overlap — DETECT_ANOMALIES requires evaluation
     timestamps to be AFTER the last training timestamp. #}

  {# Create training view (historical baseline, excludes last 30d) #}
  {% do log("Creating anomaly training + detection views...", info=True) %}

  {% call statement('create_train_view') %}
    CREATE OR REPLACE TEMPORARY VIEW AD_ANALYTICS.GOLD._ANOMALY_TRAINING AS
    SELECT * FROM AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS
    WHERE SALE_DATE < DATEADD('DAY', -30, CURRENT_DATE())
  {% endcall %}

  {% call statement('create_detect_view') %}
    CREATE OR REPLACE TEMPORARY VIEW AD_ANALYTICS.GOLD._ANOMALY_DETECTION AS
    SELECT * FROM AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS
    WHERE SALE_DATE >= DATEADD('DAY', -30, CURRENT_DATE())
  {% endcall %}

  {# --- Revenue anomalies --- #}
  {% do log("Training revenue anomaly model...", info=True) %}

  {% call statement('train_rev_anomaly') %}
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.REVENUE_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_TRAINING'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_REVENUE',
        LABEL_COLNAME => ''
    )
  {% endcall %}

  {% do log("Detecting revenue anomalies...", info=True) %}

  {% call statement('detect_rev') %}
    INSERT OVERWRITE INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS, 'revenue', Y, FORECAST, IS_ANOMALY, PERCENTILE, DISTANCE,
        CURRENT_TIMESTAMP()
    FROM TABLE(AD_ANALYTICS.GOLD.REVENUE_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_DETECTION'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_REVENUE'
    ))
  {% endcall %}

  {# --- Orders anomalies --- #}
  {% do log("Training orders anomaly model...", info=True) %}

  {% call statement('train_ord_anomaly') %}
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.ORDERS_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_TRAINING'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_ORDERS',
        LABEL_COLNAME => ''
    )
  {% endcall %}

  {% do log("Detecting order anomalies...", info=True) %}

  {% call statement('detect_ord') %}
    INSERT INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS, 'orders', Y, FORECAST, IS_ANOMALY, PERCENTILE, DISTANCE,
        CURRENT_TIMESTAMP()
    FROM TABLE(AD_ANALYTICS.GOLD.ORDERS_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_DETECTION'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_ORDERS'
    ))
  {% endcall %}

  {# --- Margin anomalies --- #}
  {% do log("Training margin anomaly model...", info=True) %}

  {% call statement('train_margin_anomaly') %}
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.MARGIN_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_TRAINING'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_MARGIN_PCT',
        LABEL_COLNAME => ''
    )
  {% endcall %}

  {% do log("Detecting margin anomalies...", info=True) %}

  {% call statement('detect_margin') %}
    INSERT INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS, 'margin', Y, FORECAST, IS_ANOMALY, PERCENTILE, DISTANCE,
        CURRENT_TIMESTAMP()
    FROM TABLE(AD_ANALYTICS.GOLD.MARGIN_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD._ANOMALY_DETECTION'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_MARGIN_PCT'
    ))
  {% endcall %}

  {% do log("Anomaly detection complete.", info=True) %}
{% endmacro %}


{% macro train_all_ml_models() %}
  {# Run all ML training: forecast + anomaly detection #}
  {% do log("=== Starting ML model training ===", info=True) %}
  {{ train_caliber_forecast() }}
  {{ train_revenue_forecast() }}
  {{ train_anomaly_models() }}
  {% do log("=== All ML models trained ===", info=True) %}
{% endmacro %}
