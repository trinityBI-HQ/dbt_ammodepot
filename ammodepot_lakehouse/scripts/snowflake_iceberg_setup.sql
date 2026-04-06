-- =============================================================================
-- Snowflake Iceberg Integration Setup
-- =============================================================================
-- Run as ACCOUNTADMIN (one-time setup)
-- After Step 1, run DESCRIBE to get Snowflake IAM ARN + External ID,
-- then update the AWS IAM trust policy before proceeding to Step 2.
-- =============================================================================

-- =============================================================================
-- STEP 1: Create Catalog Integration + External Volume (ACCOUNTADMIN)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Catalog Integration: connects Snowflake to AWS Glue catalog
CREATE OR REPLACE CATALOG INTEGRATION lakehouse_glue_catalog
    CATALOG_SOURCE = GLUE
    CATALOG_NAMESPACE = 'ammodepot_silver'  -- default namespace, can query others too
    TABLE_FORMAT = ICEBERG
    GLUE_AWS_ROLE_ARN = 'arn:aws:iam::746669199691:role/snowflake-lakehouse-role'
    GLUE_CATALOG_ID = '746669199691'
    GLUE_REGION = 'us-east-1'
    ENABLED = TRUE;

-- External Volume: grants Snowflake read access to S3 Iceberg data
CREATE OR REPLACE EXTERNAL VOLUME lakehouse_s3_volume
    STORAGE_LOCATIONS = (
        (
            NAME = 'ammodepot-lakehouse'
            STORAGE_BASE_URL = 's3://ammodepot-lakehouse/iceberg/'
            STORAGE_PROVIDER = 'S3'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::746669199691:role/snowflake-lakehouse-role'
        )
    );

-- =============================================================================
-- STEP 1b: Get Snowflake's IAM ARN + External ID for trust policy
-- =============================================================================
-- Run these and note the values for updating the IAM trust policy:

DESCRIBE CATALOG INTEGRATION lakehouse_glue_catalog;
-- Look for: GLUE_AWS_IAM_USER_ARN and GLUE_AWS_EXTERNAL_ID

DESCRIBE EXTERNAL VOLUME lakehouse_s3_volume;
-- Look for: STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID

-- =============================================================================
-- STEP 2: After updating IAM trust policy, grant access to TRANSFORMER_ROLE
-- =============================================================================

USE ROLE ACCOUNTADMIN;

GRANT USAGE ON INTEGRATION lakehouse_glue_catalog TO ROLE TRANSFORMER_ROLE;
GRANT USAGE ON EXTERNAL VOLUME lakehouse_s3_volume TO ROLE TRANSFORMER_ROLE;

-- =============================================================================
-- STEP 3: Create Iceberg tables in AD_ANALYTICS (TRANSFORMER_ROLE)
-- =============================================================================
-- These read from Glue catalog — no data copy, Snowflake queries S3 directly.

USE ROLE TRANSFORMER_ROLE;
USE DATABASE AD_ANALYTICS;
USE WAREHOUSE ETL_WH;

-- Create a schema for lakehouse Iceberg tables (keeps them separate from dbt-managed tables)
CREATE SCHEMA IF NOT EXISTS LAKEHOUSE_SILVER;
CREATE SCHEMA IF NOT EXISTS LAKEHOUSE_GOLD;

-- Example: Create one Silver Iceberg table
-- Snowflake reads from Glue catalog + S3 External Volume
CREATE OR REPLACE ICEBERG TABLE LAKEHOUSE_SILVER.FISHBOWL_SO
    EXTERNAL_VOLUME = 'lakehouse_s3_volume'
    CATALOG = 'lakehouse_glue_catalog'
    CATALOG_TABLE_NAME = 'fishbowl_so'
    CATALOG_NAMESPACE = 'ammodepot_silver';

-- Verify it works
SELECT count(*) FROM LAKEHOUSE_SILVER.FISHBOWL_SO;

-- =============================================================================
-- STEP 4: Create all Silver + Gold Iceberg tables (automated)
-- =============================================================================
-- Run snowflake_iceberg_tables.py to generate CREATE ICEBERG TABLE for all tables
