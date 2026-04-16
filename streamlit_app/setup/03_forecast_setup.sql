-- =============================================================================
-- Demand Forecasting + Anomaly Detection — Bootstrap Setup
-- Run as ACCOUNTADMIN (one-time setup)
--
-- Creates:
--   1. INT_DAILY_SALES_BY_CALIBER — training input view (dbt-managed)
--   2. V_DAILY_REVENUE — revenue training input view
--   3. INT_DAILY_SALES_METRICS — anomaly detection training view
--   4. F_FORECAST — Gold table for predictions
--   5. F_ANOMALIES — Gold table for detected anomalies
--   6. SP_TRAIN_FORECAST — stored procedure (forecast + anomaly detection)
--   7. TASK_DAILY_FORECAST — weekly scheduled task (Sunday 4am UTC)
--   8. RBAC grants
-- =============================================================================

-- ── Prerequisites ───────────────────────────────────────────────────────────
USE ROLE ACCOUNTADMIN;

-- TRANSFORMER_ROLE needs EXECUTE TASK to own and manage tasks
GRANT EXECUTE TASK ON ACCOUNT TO ROLE TRANSFORMER_ROLE;

-- ── 1. Training Input View: Daily Units by Caliber ──────────────────────────
-- MANAGED BY dbt: ammodepot/models/gold/intermediate/int_daily_sales_by_caliber.sql
-- Run `dbt build --select int_daily_sales_by_caliber` if not yet built.

USE ROLE TRANSFORMER_ROLE;
USE SCHEMA AD_ANALYTICS.GOLD;

-- ── 2. Training Input View: Daily Total Revenue ─────────────────────────────

CREATE OR REPLACE VIEW AD_ANALYTICS.GOLD.V_DAILY_REVENUE AS
SELECT
    CREATED_AT::DATE       AS SALE_DATE,
    SUM(ROW_TOTAL)         AS TOTAL_REVENUE
FROM AD_ANALYTICS.GOLD.F_SALES
WHERE STATUS IN ('COMPLETE', 'PROCESSING', 'UNVERIFIED')
GROUP BY 1;

-- ── 3. Predictions Table ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS AD_ANALYTICS.GOLD.F_FORECAST (
    CALIBER         VARCHAR,
    FORECAST_DATE   DATE,
    PREDICTED_UNITS NUMBER(18,4),
    LOWER_BOUND     NUMBER(18,4),
    UPPER_BOUND     NUMBER(18,4),
    FORECAST_TYPE   VARCHAR,       -- 'caliber' or 'revenue'
    TRAINED_AT      TIMESTAMP_NTZ
);

-- ── 3b. Anomaly Detection: Daily Sales Metrics View ─────────────────────────
-- MANAGED BY dbt: ammodepot/models/gold/intermediate/int_daily_sales_metrics.sql
-- Run `dbt build --select int_daily_sales_metrics` if not yet built.

-- ── 3c. Anomaly Detection: Results Table ────────────────────────────────────

CREATE TABLE IF NOT EXISTS AD_ANALYTICS.GOLD.F_ANOMALIES (
    ANOMALY_DATE    DATE,
    METRIC_NAME     VARCHAR,        -- 'revenue', 'orders', 'margin'
    ACTUAL_VALUE    NUMBER(18,4),
    EXPECTED_VALUE  NUMBER(18,4),
    IS_ANOMALY      BOOLEAN,
    PERCENTILE      NUMBER(18,6),
    DISTANCE        NUMBER(18,6),
    TRAINED_AT      TIMESTAMP_NTZ
);

-- ── 4. Stored Procedure ─────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE AD_ANALYTICS.GOLD.SP_TRAIN_FORECAST()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Step 1: Train per-caliber forecast model
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST AD_ANALYTICS.GOLD.CALIBER_FORECAST(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_BY_CALIBER'),
        SERIES_COLNAME => 'CALIBER',
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'UNITS_SOLD'
    );

    -- Step 2: Generate 30-day caliber predictions (INSERT OVERWRITE = atomic replace)
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
    ));

    -- Step 3: Train single-series revenue forecast
    CREATE OR REPLACE SNOWFLAKE.ML.FORECAST AD_ANALYTICS.GOLD.REVENUE_FORECAST(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.V_DAILY_REVENUE'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'TOTAL_REVENUE'
    );

    -- Step 4: Append revenue predictions (INSERT not OVERWRITE — caliber rows already there)
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
    ));

    -- Step 5: Train anomaly detection model on daily revenue
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.REVENUE_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_REVENUE',
        LABEL_COLNAME => ''
    );

    -- Step 6: Detect anomalies in last 30 days and write to F_ANOMALIES
    INSERT OVERWRITE INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS              AS ANOMALY_DATE,
        'revenue'       AS METRIC_NAME,
        Y               AS ACTUAL_VALUE,
        FORECAST        AS EXPECTED_VALUE,
        IS_ANOMALY,
        PERCENTILE,
        DISTANCE,
        CURRENT_TIMESTAMP() AS TRAINED_AT
    FROM TABLE(AD_ANALYTICS.GOLD.REVENUE_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_REVENUE'
    ))
    WHERE TS >= DATEADD('DAY', -30, CURRENT_DATE());

    -- Step 7: Train + detect anomalies on daily orders
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.ORDERS_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_ORDERS',
        LABEL_COLNAME => ''
    );

    INSERT INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS              AS ANOMALY_DATE,
        'orders'        AS METRIC_NAME,
        Y               AS ACTUAL_VALUE,
        FORECAST        AS EXPECTED_VALUE,
        IS_ANOMALY,
        PERCENTILE,
        DISTANCE,
        CURRENT_TIMESTAMP() AS TRAINED_AT
    FROM TABLE(AD_ANALYTICS.GOLD.ORDERS_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_ORDERS'
    ))
    WHERE TS >= DATEADD('DAY', -30, CURRENT_DATE());

    -- Step 8: Train + detect anomalies on daily margin %
    CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION AD_ANALYTICS.GOLD.MARGIN_ANOMALY(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_MARGIN_PCT',
        LABEL_COLNAME => ''
    );

    INSERT INTO AD_ANALYTICS.GOLD.F_ANOMALIES
    SELECT
        TS              AS ANOMALY_DATE,
        'margin'        AS METRIC_NAME,
        Y               AS ACTUAL_VALUE,
        FORECAST        AS EXPECTED_VALUE,
        IS_ANOMALY,
        PERCENTILE,
        DISTANCE,
        CURRENT_TIMESTAMP() AS TRAINED_AT
    FROM TABLE(AD_ANALYTICS.GOLD.MARGIN_ANOMALY!DETECT_ANOMALIES(
        INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS'),
        TIMESTAMP_COLNAME => 'SALE_DATE',
        TARGET_COLNAME => 'DAILY_MARGIN_PCT'
    ))
    WHERE TS >= DATEADD('DAY', -30, CURRENT_DATE());

    RETURN 'Forecast + anomaly detection complete: ' || CURRENT_TIMESTAMP()::VARCHAR;
END;
$$;

-- ── 5. Daily Task (4am UTC) ─────────────────────────────────────────────────

CREATE OR REPLACE TASK AD_ANALYTICS.GOLD.TASK_DAILY_FORECAST
    WAREHOUSE = ETL_WH
    SCHEDULE = 'USING CRON 0 4 * * 0 UTC'
    COMMENT = 'Weekly demand forecast (Sunday 4am UTC): trains ML.FORECAST on sales by caliber, writes 30d predictions to F_FORECAST'
AS
    CALL AD_ANALYTICS.GOLD.SP_TRAIN_FORECAST();

-- Enable the task
ALTER TASK AD_ANALYTICS.GOLD.TASK_DAILY_FORECAST RESUME;

-- ── 6. RBAC Grants ──────────────────────────────────────────────────────────
USE ROLE ACCOUNTADMIN;

GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.INT_DAILY_SALES_BY_CALIBER TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.V_DAILY_REVENUE TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_FORECAST TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_FORECAST TO ROLE POWERBI_READONLY_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_FORECAST TO ROLE STREAMLIT_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.INT_DAILY_SALES_METRICS TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_ANOMALIES TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_ANOMALIES TO ROLE POWERBI_READONLY_ROLE;
GRANT SELECT ON TABLE AD_ANALYTICS.GOLD.F_ANOMALIES TO ROLE STREAMLIT_ROLE;
