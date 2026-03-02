## Data model used in Power BI (VERY IMPORTANT)
<!-- -- Dataflow Gen1 - Data Warehouse - SNOWFLAKE - Scheduled refresh > OFF
f_inventory - AD_AIRBYTE.AIRBYTE_SCHEMA.F_INVENTORYVIEW
f_shippment - AD_AIRBYTE.TEST_DTO.F_SHIPPMENT
d_store - AD_AIRBYTE.TEST_DTO.D_STORE
d_user - PC_FIVETRAN_DB.MAGENTO_MYSQL_AMMUNITIONDEPOT_PROD2.D_USER
f_sales - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS
d_customer - AD_AIRBYTE.TEST_DTO.D_CUSTOMERSEGMENTATION
d_CustomerUpdated - AD_AIRBYTE.TEST_DTO.D_CUSTOMERUPDATED
f_pos - AD_AIRBYTE.AIRBYTE_SCHEMA.F_POS -->


-- Dataflow Gen1 - Data Warehouse Redshift - SNOWFLAKE+REDSHIFT - Scheduled refresh > HOURLY
d_customer - gold.d_customer_segmentation
d_product - gold.d_product
d_product_bundle - gold.d_product_bundle
d_store - gold.d_store
f_sales - gold.f_sales
f_shippment - gold.f_shippment
f_inventoryview - gold.f_inventoryview
f_pos - gold.f_pos
d_vendor - gold.d_vendor
f_sales_realtime - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME_LASTDAYS
d_product_realtime - AD_AIRBYTE.AD_REALTIME.D_PRODUCT_REALTIME

-- Dataflow Gen1 - Once Per Day Updates - SNOWFLAKE - Scheduled refresh > DAILY
f_cohort - AD_AIRBYTE.TEST_DTO.F_COHORT
f_cohortUpdates - AD_AIRBYTE.TEST_DTO.F_COHORTDETAILED

-- Dataflow Gen1 - SALES OVERVIEW REALTIME - SNOWFLAKE - VIEW
F_SALES_REALTIME - AD_AIRBYTE.AD_REALTIME.F_SALES_REALTIME


<!-- -- Dataflow Gen1 - Product List - SNOWFLAKE - Scheduled refresh > OFF
-- SOURCE POWER BI - SOURCE WH/INVESTIGATE
d_product - AD_AIRBYTE.TEST_DTO.D_PRODUCT
d_product_bundle - AD_AIRBYTE.TEST_DTO.INVENTORYCONVERSION
d_vendor - AD_AIRBYTE.AIRBYTE_SCHEMA.D_VENDOR -->
