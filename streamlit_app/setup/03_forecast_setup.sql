-- =============================================================================
-- Demand Forecasting — Bootstrap Setup
-- Run as ACCOUNTADMIN (one-time setup)
--
-- Creates:
--   1. INT_DAILY_SALES_BY_CALIBER — training input view
--   2. V_DAILY_REVENUE — revenue training input view
--   3. F_FORECAST — Gold table for predictions
--   4. SP_TRAIN_FORECAST — stored procedure (trains model + writes predictions)
--   5. TASK_DAILY_FORECAST — daily scheduled task (4am UTC)
--   6. RBAC grants
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

    RETURN 'Forecast training complete: ' || CURRENT_TIMESTAMP()::VARCHAR;
END;
$$;

-- ── 5. Daily Task (4am UTC) ─────────────────────────────────────────────────

CREATE OR REPLACE TASK AD_ANALYTICS.GOLD.TASK_DAILY_FORECAST
    WAREHOUSE = ETL_WH
    SCHEDULE = 'USING CRON 0 4 * * * UTC'
    COMMENT = 'Daily demand forecast: trains ML.FORECAST on sales by caliber, writes 30d predictions to F_FORECAST'
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
