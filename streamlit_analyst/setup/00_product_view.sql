-- =============================================================================
-- D_PRODUCT_ANALYST — Thin view with UPPERCASE unquoted column names
--
-- D_PRODUCT uses mixed-case quoted columns ("Caliber", "Product Name", etc.)
-- which break Cortex Analyst's CTE generation. This view aliases all columns
-- to UPPERCASE unquoted names so Cortex can reference them without issues.
--
-- Run BEFORE 01_bootstrap.sql. Does not modify D_PRODUCT (PBI depends on it).
-- =============================================================================

USE ROLE TRANSFORMER_ROLE;
USE SCHEMA AD_ANALYTICS.GOLD;

CREATE OR REPLACE VIEW AD_ANALYTICS.GOLD.D_PRODUCT_ANALYST AS
SELECT
    "Product ID"        AS PRODUCT_ID,
    SKU,
    "Product Name"      AS PRODUCT_NAME,
    "Caliber"           AS CALIBER,
    "Manufacturer SKU"  AS MANUFACTURER,
    "Projectile"        AS PROJECTILE,
    "Vendor"            AS PRODUCT_VENDOR,
    USE_TYPE_CATEGORY,
    "Primary Category"  AS PRIMARY_CATEGORY,
    "Discontinued"      AS DISCONTINUED,
    "Unit Type"         AS UNIT_TYPE,
    AVGCOST,
    LASTVENDORCOST,
    "General Purpose"   AS GENERAL_PURPOSE
FROM AD_ANALYTICS.GOLD.D_PRODUCT;

-- Grant to viewer roles (same as D_PRODUCT)
USE ROLE ACCOUNTADMIN;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.D_PRODUCT_ANALYST TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.D_PRODUCT_ANALYST TO ROLE POWERBI_READONLY_ROLE;
GRANT SELECT ON VIEW AD_ANALYTICS.GOLD.D_PRODUCT_ANALYST TO ROLE STREAMLIT_ROLE;
