## Data model used in Power BI (VERY IMPORTANT)

> Migration plan: [docs/POWERBI_MIGRATION_PLAN.md](docs/POWERBI_MIGRATION_PLAN.md)
> Snowflake access setup: [docs/snowflake_access_setup.md](docs/snowflake_access_setup.md) (section 11)

---

### TARGET STATE (post-migration)

All tables from `AD_ANALYTICS.GOLD` via POWERBI_ROLE + POWERBI_WH.

-- Dataflow Gen1 - Data Warehouse (Core) - SNOWFLAKE - Scheduled refresh > HOURLY
d_customer          - AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION
d_product           - AD_ANALYTICS.GOLD.D_PRODUCT
d_product_bundle    - AD_ANALYTICS.GOLD.D_PRODUCT_BUNDLE
d_store             - AD_ANALYTICS.GOLD.D_STORE
d_vendor            - AD_ANALYTICS.GOLD.D_VENDOR
f_sales             - AD_ANALYTICS.GOLD.F_SALES
f_shippment         - AD_ANALYTICS.GOLD.F_SHIPPMENT
f_inventoryview     - AD_ANALYTICS.GOLD.F_INVENTORYVIEW
f_pos               - AD_ANALYTICS.GOLD.F_POS
f_cohort            - AD_ANALYTICS.GOLD.F_COHORT
f_cohort_detailed   - AD_ANALYTICS.GOLD.F_COHORT_DETAILED

-- Dataflow Gen1 - Sales Realtime - SNOWFLAKE - Scheduled refresh > 15-MIN
f_sales_realtime    - AD_ANALYTICS.GOLD.F_SALES_REALTIME

---

### CURRENT STATE (pre-migration)

<!-- Dataflow Gen1 - Data Warehouse - SNOWFLAKE - Scheduled refresh > OFF (STALE since 12/31/25)
f_inventory       - AD_AIRBYTE.AIRBYTE_SCHEMA.F_INVENTORYVIEW
f_shippment       - AD_AIRBYTE.TEST_DTO.F_SHIPPMENT
d_store           - AD_AIRBYTE.TEST_DTO.D_STORE
d_user            - PC_FIVETRAN_DB.MAGENTO_MYSQL_AMMUNITIONDEPOT_PROD2.D_USER
f_sales           - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS
d_customer        - AD_AIRBYTE.TEST_DTO.D_CUSTOMERSEGMENTATION
d_CustomerUpdated - AD_AIRBYTE.TEST_DTO.D_CUSTOMERUPDATED
f_pos             - AD_AIRBYTE.AIRBYTE_SCHEMA.F_POS -->

-- Dataflow Gen1 - Data Warehouse Redshift - SNOWFLAKE+REDSHIFT - Scheduled refresh > HOURLY
d_customer          - Redshift gold.d_customer_segmentation
d_product           - Redshift gold.d_product
d_product_bundle    - Redshift gold.d_product_bundle
d_store             - Redshift gold.d_store
f_sales             - Redshift gold.f_sales
f_shippment         - Redshift gold.f_shippment
f_inventoryview     - Redshift gold.f_inventoryview
f_pos               - Redshift gold.f_pos
d_vendor            - Redshift gold.d_vendor
f_sales_realtime    - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS
d_product_realtime  - AD_AIRBYTE.AD_REALTIME.D_PRODUCT_REALTIME

-- Dataflow Gen1 - Once Per Day Updates - SNOWFLAKE - Scheduled refresh > DAILY
f_cohort            - AD_AIRBYTE.TEST_DTO.F_COHORT
f_cohortUpdates     - AD_AIRBYTE.TEST_DTO.F_COHORTDETAILED

-- Dataflow Gen1 - SALES OVERVIEW REALTIME - SNOWFLAKE - VIEW
F_SALES_REALTIME    - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME

<!-- Dataflow Gen1 - Product List - SNOWFLAKE - Scheduled refresh > OFF
d_product         - AD_AIRBYTE.TEST_DTO.D_PRODUCT
d_product_bundle  - AD_AIRBYTE.TEST_DTO.INVENTORYCONVERSION
d_vendor          - AD_AIRBYTE.AIRBYTE_SCHEMA.D_VENDOR -->
