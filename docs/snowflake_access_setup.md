# Snowflake Access Setup Guide

Setup guide for two service roles on Snowflake:

- **AIRBYTE_ROLE** -- CDC ingestion via Airbyte (OWNERSHIP on `AD_AIRBYTE`)
- **TRANSFORMER_ROLE** -- dbt transformation (read source data, write silver/gold schemas)

Neither role should use ACCOUNTADMIN. Execute the steps in order -- each step depends on the previous ones.

---

## 1. Create roles

Both roles must exist before any grants can reference them.

```sql
USE ROLE SECURITYADMIN;

-- Ingestion role (Airbyte)
CREATE ROLE IF NOT EXISTS AIRBYTE_ROLE
    COMMENT = 'Role for Airbyte CDC ingestion - owns AD_AIRBYTE database';

-- Transformation role (dbt)
CREATE ROLE IF NOT EXISTS TRANSFORMER_ROLE
    COMMENT = 'Role for dbt transformation - reads source data, writes silver/gold schemas';

-- Maintain role hierarchy
GRANT ROLE AIRBYTE_ROLE TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER_ROLE TO ROLE SYSADMIN;
```

## 2. Create warehouse

A single shared warehouse keeps costs low at XSMALL scale (1 credit/hour, billed per-second with 60s minimum). Both roles share `ETL_WH` -- use `QUERY_TAG` on each service account for per-service cost attribution in `QUERY_HISTORY`.

```sql
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS ETL_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 7200
    COMMENT = 'Shared warehouse for Airbyte ingestion and dbt transformation';

-- Grant warehouse access to both roles
GRANT USAGE ON WAREHOUSE ETL_WH TO ROLE AIRBYTE_ROLE;
GRANT OPERATE ON WAREHOUSE ETL_WH TO ROLE AIRBYTE_ROLE;

GRANT USAGE ON WAREHOUSE ETL_WH TO ROLE TRANSFORMER_ROLE;
GRANT OPERATE ON WAREHOUSE ETL_WH TO ROLE TRANSFORMER_ROLE;
```

> **Sizing reference:** XSMALL = 1 credit/hour. Each size up doubles credits (Small=2, Medium=4, Large=8). Scale up if dbt runs exceed 30 min or Airbyte syncs queue behind transformations. If workloads diverge, split into dedicated warehouses later.

## 3. Grant database ownership to Airbyte

Airbyte requires OWNERSHIP for internal staging (stages, file formats, temp tables).
Since AD_AIRBYTE is a dedicated Airbyte database, granting OWNERSHIP is the correct approach.

```sql
-- ACCOUNTADMIN: transfer ownership (one-time operation)
USE ROLE ACCOUNTADMIN;

GRANT OWNERSHIP ON DATABASE AD_AIRBYTE TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;

-- IMPORTANT: Snowflake ownership does NOT cascade to pre-existing child objects.
-- If schemas or tables already exist (e.g., created by ACCOUNTADMIN), transfer them explicitly:
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE AD_AIRBYTE TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE."airbyte_internal" TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL STAGES IN SCHEMA AD_AIRBYTE."airbyte_internal" TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
```

> `COPY CURRENT GRANTS` preserves any existing access (e.g., Power BI read access).
> After this, AIRBYTE_ROLE owns the database and no further ACCOUNTADMIN usage is needed for Airbyte operations.
>
> **Ownership inheritance caveat:** `GRANT OWNERSHIP ON DATABASE` does NOT retroactively transfer ownership of schemas, tables, or stages already inside it. Each level (database → schema → table/stage) requires an explicit grant. If Airbyte fails with "current role has no privileges on it", grant ownership on the specific level that's failing.

## 4. Create schemas and grant transformer privileges

dbt needs to own the `silver` and `gold` schemas it writes to, and have read access to Airbyte's source schemas.

### Create transformation schemas

```sql
-- Run as AIRBYTE_ROLE since it owns the database
USE ROLE AIRBYTE_ROLE;
USE DATABASE AD_AIRBYTE;

CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Silver layer - cleaned, typed views from source data';
CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Gold layer - business-ready tables and intermediate views';

-- Transfer schema ownership to TRANSFORMER_ROLE
GRANT OWNERSHIP ON SCHEMA SILVER TO ROLE TRANSFORMER_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA GOLD TO ROLE TRANSFORMER_ROLE COPY CURRENT GRANTS;

-- Grant future table ownership so Airbyte-created tables are auto-owned
GRANT OWNERSHIP ON FUTURE TABLES IN SCHEMA AD_FISHBOWL TO ROLE AIRBYTE_ROLE;
GRANT OWNERSHIP ON FUTURE TABLES IN SCHEMA AD_MAGENTO TO ROLE AIRBYTE_ROLE;
GRANT OWNERSHIP ON FUTURE TABLES IN SCHEMA AIRBYTE_SCHEMA TO ROLE AIRBYTE_ROLE;
```

> **If migrating from a previous Airbyte setup** where tables were created by another role (e.g., ACCOUNTADMIN), transfer existing table ownership before running syncs:
> ```sql
> GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AD_FISHBOWL TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
> GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AD_MAGENTO TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
> GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AIRBYTE_SCHEMA TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
> ```

### Grant read access to source data

TRANSFORMER_ROLE needs SELECT on all current and future Airbyte-managed schemas and tables:

```sql
USE ROLE AIRBYTE_ROLE;

-- TRANSFORMER_ROLE needs USAGE on the database itself to see it
GRANT USAGE ON DATABASE AD_AIRBYTE TO ROLE TRANSFORMER_ROLE;

GRANT USAGE ON ALL SCHEMAS IN DATABASE AD_AIRBYTE TO ROLE TRANSFORMER_ROLE;
GRANT SELECT ON ALL TABLES IN DATABASE AD_AIRBYTE TO ROLE TRANSFORMER_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AD_AIRBYTE TO ROLE TRANSFORMER_ROLE;
GRANT SELECT ON FUTURE TABLES IN DATABASE AD_AIRBYTE TO ROLE TRANSFORMER_ROLE;
```

> TRANSFORMER_ROLE now owns `SILVER` and `GOLD` schemas (can create/drop objects) and has SELECT-only access to all Airbyte source schemas.
> Repeat the future grants pattern above for additional downstream roles (e.g., `POWERBI_ROLE`).

## 5. Generate RSA key pairs

Generate a **separate** key pair for each service account. Never share keys between services.

Run from the project root (`projects/ammodepot/`):

```bash
cd projects/ammodepot/

# --- Airbyte key pair ---
openssl genrsa 4096 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out airbyte_rsa_key.p8
openssl rsa -in airbyte_rsa_key.p8 -pubout -out airbyte_rsa_key.pub
grep -v "PUBLIC KEY" airbyte_rsa_key.pub | tr -d '\n'

# --- dbt key pair ---
openssl genrsa 4096 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out dbt_rsa_key.p8
openssl rsa -in dbt_rsa_key.p8 -pubout -out dbt_rsa_key.pub
grep -v "PUBLIC KEY" dbt_rsa_key.pub | tr -d '\n'
```

> Key must be PKCS#8 format. Airbyte and Snowflake both reject PKCS#1 (`BEGIN RSA PRIVATE KEY`).
> 4096 bits recommended for keys with infrequent rotation. Minimum is 2048 bits.
> Add `*.p8` and `*.pub` to `.gitignore`. Store `.p8` files in a secrets manager (AWS Secrets Manager, Vault, etc.), never in source control.


## 6. Create service accounts

`TYPE = SERVICE` disables interactive login (no web UI, no password). Authentication is key-pair only.

```sql
USE ROLE SECURITYADMIN;

-- Airbyte service account
CREATE USER SVC_AIRBYTE
    TYPE = SERVICE
    DEFAULT_ROLE = AIRBYTE_ROLE
    DEFAULT_WAREHOUSE = ETL_WH
    DEFAULT_NAMESPACE = AD_AIRBYTE
    RSA_PUBLIC_KEY = '<paste single-line public key from airbyte_rsa_key.pub>'
    COMMENT = 'Service account for Airbyte CDC ingestion';

GRANT ROLE AIRBYTE_ROLE TO USER SVC_AIRBYTE;
ALTER USER SVC_AIRBYTE SET QUERY_TAG = 'airbyte-cdc-ingestion';

-- dbt service account
CREATE USER SVC_DBT
    TYPE = SERVICE
    DEFAULT_ROLE = TRANSFORMER_ROLE
    DEFAULT_WAREHOUSE = ETL_WH
    DEFAULT_NAMESPACE = AD_AIRBYTE
    RSA_PUBLIC_KEY = '<paste single-line public key from dbt_rsa_key.pub>'
    COMMENT = 'Service account for dbt transformation';

GRANT ROLE TRANSFORMER_ROLE TO USER SVC_DBT;
ALTER USER SVC_DBT SET QUERY_TAG = 'dbt-transformation';
```

> `TYPE = SERVICE` requires Snowflake 2023_07 behavior change bundle (enabled by default since late 2023).
> You cannot set `PASSWORD` on a `TYPE = SERVICE` user -- this is by design.

### Verify key assignments

```sql
DESCRIBE USER SVC_AIRBYTE;
DESCRIBE USER SVC_DBT;
-- Look for RSA_PUBLIC_KEY_FP -- should show a SHA-256 fingerprint for each
```

Compare with local fingerprints:

```bash
openssl rsa -in projects/ammodepot/airbyte_rsa_key.p8 -pubout -outform DER 2>/dev/null | openssl dgst -sha256 -binary | openssl enc -base64
openssl rsa -in projects/ammodepot/dbt_rsa_key.p8 -pubout -outform DER 2>/dev/null | openssl dgst -sha256 -binary | openssl enc -base64
```

## 7. Security hardening


### 7.1 Object tagging

Tag resources for governance and cost attribution:

```sql
USE ROLE ACCOUNTADMIN;

CREATE TAG IF NOT EXISTS cost_center;
CREATE TAG IF NOT EXISTS environment;

ALTER WAREHOUSE ETL_WH SET TAG cost_center = 'data-engineering';
ALTER DATABASE AD_AIRBYTE SET TAG environment = 'production';
ALTER SCHEMA AD_AIRBYTE.SILVER SET TAG environment = 'production';
ALTER SCHEMA AD_AIRBYTE.GOLD SET TAG environment = 'production';
```

## 8. Validate

### 8.1 Test Airbyte role

```sql
USE ROLE AIRBYTE_ROLE;
USE WAREHOUSE ETL_WH;
USE DATABASE AD_AIRBYTE;

CREATE SCHEMA IF NOT EXISTS _validation_test;
CREATE TABLE _validation_test._test_connectivity (id INT);
DROP TABLE _validation_test._test_connectivity;
DROP SCHEMA _validation_test;

SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
-- Expected: AIRBYTE_ROLE, ETL_WH, AD_AIRBYTE
```

### 8.2 Test transformer role

```sql
USE ROLE TRANSFORMER_ROLE;
USE WAREHOUSE ETL_WH;
USE DATABASE AD_AIRBYTE;

-- Verify schema ownership (can create objects)
USE SCHEMA SILVER;
CREATE TABLE _test_dbt (id INT);
DROP TABLE _test_dbt;

-- Verify read access to source schemas
SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA NOT IN ('SILVER', 'GOLD', 'INFORMATION_SCHEMA');

SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
-- Expected: TRANSFORMER_ROLE, ETL_WH, AD_AIRBYTE
```

### 8.3 Test key-pair connections


**Python (either user):**

```python
import snowflake.connector

conn = snowflake.connector.connect(
    account='<account_identifier>',
    user='SVC_DBT',                     # or SVC_AIRBYTE
    private_key_file='projects/ammodepot/dbt_rsa_key.p8',  # or airbyte_rsa_key.p8
    private_key_file_pwd='<passphrase>',
    warehouse='ETL_WH',
    database='AD_AIRBYTE',
    role='TRANSFORMER_ROLE',            # or AIRBYTE_ROLE
)

cur = conn.cursor()
cur.execute('SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()')
print(cur.fetchone())
cur.close()
conn.close()
```

> If the key is encrypted, you will be prompted for the passphrase (SnowSQL) or must pass it as `private_key_file_pwd` (Python).

## 9. Update Airbyte connection

In Airbyte UI, update the Snowflake destination:

| Setting | Old (bad) | New (correct) |
|---|---|---|
| Host | `account.us-east-1.snowflakecomputing.com` | same |
| Role | `ACCOUNTADMIN` | `AIRBYTE_ROLE` |
| Warehouse | `PC_FIVETRAN_WH` | `ETL_WH` |
| Database | `AD_AIRBYTE` | same |
| Default Schema | `AIRBYTE_SCHEMA` | same |
| Username | `powerbi_reader` | `SVC_AIRBYTE` |
| Authorization Method | Username and Password | **Key Pair Authentication** |
| Private Key | n/a | Paste full contents of `airbyte_rsa_key.p8` (including headers) |
| Private Key Password | n/a | Passphrase from step 5 (blank if unencrypted) |

> Airbyte expects the **private key** in PKCS#8 format, not the public key.

## 10. Key rotation

Snowflake supports two simultaneous public keys for zero-downtime rotation. Recommended cadence: **every 90 days**, or per your organization's security policy.

Apply the same procedure to both `SVC_AIRBYTE` and `SVC_DBT`:

```sql
-- 1. Generate a new key pair (repeat step 5 for the target user)

-- 2. Assign new key as secondary (both keys now active)
ALTER USER <SVC_AIRBYTE or SVC_DBT> SET RSA_PUBLIC_KEY_2 = '<new_public_key_single_line>';

-- 3. Update the service (Airbyte or dbt) to use the new private key, verify with a test

-- 4. Swap: set the new key as primary, then remove secondary
ALTER USER <SVC_AIRBYTE or SVC_DBT> SET RSA_PUBLIC_KEY = '<new_public_key_single_line>';
ALTER USER <SVC_AIRBYTE or SVC_DBT> UNSET RSA_PUBLIC_KEY_2;
```

> On the next rotation, the new key goes into `RSA_PUBLIC_KEY_2` first, then gets promoted to `RSA_PUBLIC_KEY`. The cycle alternates each rotation.

---

## Summary

### Shared warehouse

| Component | Value |
|---|---|
| Warehouse | `ETL_WH` (XSMALL, auto-suspend 120s, 1hr statement timeout) |
| Credits | 1 credit/hour, billed per-second (60s minimum per resume) |
| Cost attribution | Via `QUERY_TAG` per service account |

### Airbyte (ingestion)

| Component | Value |
|---|---|
| User | `SVC_AIRBYTE` (TYPE = SERVICE) |
| Auth | RSA key-pair (PKCS#8, 4096-bit) |
| Role | `AIRBYTE_ROLE` |
| Warehouse | `ETL_WH` (shared) |
| Access | OWNERSHIP on `AD_AIRBYTE` database |
| Auth Policy | KEYPAIR only (programmatic clients) |
| Query Tag | `airbyte-cdc-ingestion` |

### dbt (transformation)

| Component | Value |
|---|---|
| User | `SVC_DBT` (TYPE = SERVICE) |
| Auth | RSA key-pair (PKCS#8, 4096-bit) |
| Role | `TRANSFORMER_ROLE` |
| Warehouse | `ETL_WH` (shared) |
| Access | OWNERSHIP on `SILVER` and `GOLD` schemas, SELECT on source schemas |
| Auth Policy | KEYPAIR only (programmatic clients) |
| Query Tag | `dbt-transformation` |

### Power BI (consumption)

| Component | Value |
|---|---|
| User | `SVC_POWERBI` |
| Auth | Password (Power BI Service does not support key-pair natively) |
| Role | `POWERBI_ROLE` |
| Warehouse | `ETL_WH` (shared, XSMALL, auto-suspend 120s) |
| Access | SELECT on `AD_ANALYTICS.GOLD` (tables and views, current and future) |
| Query Tag | `powerbi-dataflow-refresh` |

### Streamlit in Snowflake (dashboards)

| Component | Value |
|---|---|
| App owner role | `STREAMLIT_ROLE` |
| Viewer role | `DASHBOARD_VIEWER_ROLE` |
| Auth (viewers) | SSO via SAML 2.0 (company email) |
| Auth (owner) | Owner's rights model — app queries run as `STREAMLIT_ROLE` |
| Warehouse | `ETL_WH` (shared, XSMALL, auto-suspend 120s) |
| Access | SELECT on `AD_ANALYTICS.GOLD` + CREATE STREAMLIT |
| Runtime | Warehouse (per-viewer instances, auto-suspend) |

### Why OWNERSHIP instead of individual GRANTs

Airbyte internally uses stages, file formats, and temp tables for bulk loading (COPY INTO). These require OWNERSHIP-level privileges. Individual `GRANT ALL` on schemas is not sufficient and syncs will fail.

### Why TYPE = SERVICE with key-pair

- No password to leak or rotate manually
- Cannot log in via Snowflake web UI (programmatic access only)
- Key rotation with zero downtime (dual key support)
- Auditable: fingerprint is visible in `DESCRIBE USER`
- Authentication policy enforces key-pair only, preventing misconfiguration

### Role hierarchy

```text
ACCOUNTADMIN
├── SECURITYADMIN         → Roles, users, auth policies
└── SYSADMIN              → Warehouses, grants
    ├── AIRBYTE_ROLE      → OWNERSHIP on AD_AIRBYTE database
    │   └── SVC_AIRBYTE   → Airbyte CDC ingestion (key-pair auth)
    ├── TRANSFORMER_ROLE  → OWNERSHIP on AD_ANALYTICS SILVER/GOLD, SELECT on AD_AIRBYTE
    │   └── SVC_DBT       → dbt transformation (key-pair auth)
    ├── POWERBI_ROLE      → SELECT on AD_ANALYTICS.GOLD (read-only)
    │   └── SVC_POWERBI   → Power BI dataflows (password auth)
    ├── STREAMLIT_ROLE    → Owns Streamlit apps, SELECT on AD_ANALYTICS.GOLD
    │   └── (app runs with this role's privileges — owner's rights)
    └── DASHBOARD_VIEWER_ROLE  → USAGE on Streamlit apps (viewer access)
        ├── SSO users     → Company email login via SAML 2.0
        └── TEMP_USER_DELETE_AFTER_PROD → Pre-SSO testing (password auth, DELETE after prod)
```

### Role usage reference

| Role | Used for |
|---|---|
| `SECURITYADMIN` | Create roles, create users, assign roles, auth policies |
| `SYSADMIN` | Create warehouses, grant warehouse access |
| `ACCOUNTADMIN` | Transfer database ownership (one-time), object tags |
| `AIRBYTE_ROLE` | CDC ingestion, owns `AD_AIRBYTE` database |
| `TRANSFORMER_ROLE` | dbt transformation, owns `AD_ANALYTICS` SILVER/GOLD schemas |
| `POWERBI_ROLE` | Power BI read-only access, SELECT on `AD_ANALYTICS.GOLD` |
| `STREAMLIT_ROLE` | Owns Streamlit apps, SELECT on `AD_ANALYTICS.GOLD`, CREATE STREAMLIT |
| `DASHBOARD_VIEWER_ROLE` | Views Streamlit apps via SSO, USAGE on Streamlit objects only |

### Future considerations

- **Programmatic Access Tokens (PATs):** Snowflake PATs offer scoped, short-lived authentication as an alternative to key-pair. When Airbyte adds PAT support, consider migrating for simpler credential management.
- ~~**POWERBI_ROLE:**~~ Implemented in section 11 below.
- **Network policy:** If you need IP-based access restriction in the future, apply per-user network policies (not account-level) to avoid locking yourself out.
- **Resource monitor:** If credit consumption grows, add per-warehouse resource monitors with `ON 100 PERCENT DO SUSPEND` to cap spend.
- **Warehouse split:** If Airbyte syncs and dbt runs start competing for resources (queued queries, slow syncs), split `ETL_WH` into dedicated `AIRBYTE_WH` + `TRANSFORMER_WH` with workload-specific settings.

---

## 11. Power BI access (read-only)

POWERBI_ROLE provides read-only SELECT access to `AD_ANALYTICS.GOLD` for Power BI dataflow refreshes. Unlike AIRBYTE_ROLE and TRANSFORMER_ROLE, this role uses password authentication (not key-pair) because Power BI Service does not support key-pair natively without an on-premises data gateway.

### 11.1 Create role

```sql
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS POWERBI_ROLE
    COMMENT = 'Read-only role for Power BI - SELECT on AD_ANALYTICS.GOLD only';

-- Maintain role hierarchy
GRANT ROLE POWERBI_ROLE TO ROLE SYSADMIN;
```

### 11.2 Grant warehouse access

Power BI shares `ETL_WH` with Airbyte and dbt. At XSMALL scale, workloads don't compete meaningfully. Cost attribution is handled via `QUERY_TAG` per service account — filter `QUERY_HISTORY` by `powerbi-dataflow-refresh` to isolate Power BI costs. If workloads diverge in the future, split into a dedicated `POWERBI_WH`.

```sql
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE ETL_WH TO ROLE POWERBI_ROLE;
```

### 11.3 Grant read-only access to Gold schema

POWERBI_ROLE only needs SELECT on `AD_ANALYTICS.GOLD`. No access to Silver, source schemas, or AD_AIRBYTE.

```sql
USE ROLE SYSADMIN;

-- Database and schema access
GRANT USAGE ON DATABASE AD_ANALYTICS TO ROLE POWERBI_ROLE;
GRANT USAGE ON SCHEMA AD_ANALYTICS.GOLD TO ROLE POWERBI_ROLE;

-- Current objects
GRANT SELECT ON ALL TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE POWERBI_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE POWERBI_ROLE;

-- Future objects (auto-grant when dbt creates new Gold models)
GRANT SELECT ON FUTURE TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE POWERBI_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE POWERBI_ROLE;
```

### 11.4 Create service account

SVC_POWERBI uses password authentication. Unlike SVC_AIRBYTE and SVC_DBT (TYPE = SERVICE with key-pair), this account needs password auth for Power BI Service compatibility.

```sql
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS SVC_POWERBI
    PASSWORD = '<strong-password>'
    DEFAULT_ROLE = POWERBI_ROLE
    DEFAULT_WAREHOUSE = ETL_WH
    DEFAULT_NAMESPACE = AD_ANALYTICS.GOLD
    COMMENT = 'Power BI service account - read-only access to Gold schema';

GRANT ROLE POWERBI_ROLE TO USER SVC_POWERBI;
ALTER USER SVC_POWERBI SET QUERY_TAG = 'powerbi-dataflow-refresh';
```

> Store the password in Power BI Service data source credentials. Rotate per your organization's password policy (minimum every 90 days).

### 11.5 Validate

```sql
USE ROLE POWERBI_ROLE;
USE WAREHOUSE ETL_WH;

-- Verify Gold tables are visible
SHOW TABLES IN SCHEMA AD_ANALYTICS.GOLD;
SHOW VIEWS IN SCHEMA AD_ANALYTICS.GOLD;

-- Verify SELECT works
SELECT COUNT(*) FROM AD_ANALYTICS.GOLD.D_STORE;
SELECT COUNT(*) FROM AD_ANALYTICS.GOLD.F_SALES;

-- Verify no access to source schemas
SHOW TABLES IN SCHEMA AD_AIRBYTE.AD_FISHBOWL;
-- Expected: error (no USAGE on AD_AIRBYTE)

SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE(), CURRENT_DATABASE();
-- Expected: POWERBI_ROLE, ETL_WH, AD_ANALYTICS
```

### 11.6 Power BI connection details

| Parameter | Value |
|---|---|
| Server | `iwb48385.us-east-1.snowflakecomputing.com` |
| Warehouse | `ETL_WH` |
| Database | `AD_ANALYTICS` |
| Schema | `GOLD` |
| Role | `POWERBI_ROLE` |
| User | `SVC_POWERBI` |
| Auth | Username/Password |

> See [POWERBI_MIGRATION_PLAN.md](POWERBI_MIGRATION_PLAN.md) for the full dataflow migration plan.

---

## 12. Streamlit in Snowflake (native deployment)

The Streamlit dashboard runs natively inside Snowflake (SiS). No external hosting, no service accounts — the app is a Snowflake object owned by STREAMLIT_ROLE. Users access it via SSO with their company email.

**How it works:**
- App runs under **owner's rights** — SQL queries execute with STREAMLIT_ROLE's privileges (SELECT on Gold)
- Viewers only need USAGE on the Streamlit object — they don't need direct table access
- Snowflake handles authentication, scaling, and lifecycle

### 12.1 Create roles

```sql
USE ROLE SECURITYADMIN;

-- App owner role (creates and owns Streamlit apps)
CREATE ROLE IF NOT EXISTS STREAMLIT_ROLE
    COMMENT = 'Owns Streamlit apps - SELECT on AD_ANALYTICS.GOLD + CREATE STREAMLIT';

-- Viewer role (end users who view dashboards via SSO)
CREATE ROLE IF NOT EXISTS DASHBOARD_VIEWER_ROLE
    COMMENT = 'Views Streamlit dashboards - USAGE on Streamlit objects only';

-- Maintain role hierarchy
GRANT ROLE STREAMLIT_ROLE TO ROLE SYSADMIN;
GRANT ROLE DASHBOARD_VIEWER_ROLE TO ROLE SYSADMIN;
```

### 12.2 Grant warehouse access

Both roles share `ETL_WH`. Streamlit warehouse runtime spins up per-viewer instances that auto-suspend when idle.

```sql
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE ETL_WH TO ROLE STREAMLIT_ROLE;
GRANT USAGE ON WAREHOUSE ETL_WH TO ROLE DASHBOARD_VIEWER_ROLE;
```

### 12.3 Grant STREAMLIT_ROLE data access + app creation

```sql
USE ROLE SYSADMIN;

-- Database and schema access
GRANT USAGE ON DATABASE AD_ANALYTICS TO ROLE STREAMLIT_ROLE;
GRANT USAGE ON SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;

-- Read-only on Gold (same as POWERBI_ROLE)
GRANT SELECT ON ALL TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;

-- Streamlit app creation privileges
GRANT CREATE STREAMLIT ON SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;
GRANT CREATE STAGE ON SCHEMA AD_ANALYTICS.GOLD TO ROLE STREAMLIT_ROLE;
```

### 12.4 Grant DASHBOARD_VIEWER_ROLE access to Streamlit apps

Viewers need USAGE on the database, schema, and Streamlit object — but NOT on the underlying tables.

```sql
USE ROLE SYSADMIN;

-- Database and schema navigation (required to reach the Streamlit object)
GRANT USAGE ON DATABASE AD_ANALYTICS TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT USAGE ON SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;

-- Access to all current and future Streamlit apps
GRANT USAGE ON ALL STREAMLITS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT USAGE ON FUTURE STREAMLITS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
```

### 12.5 Enable viewer identity (READ SESSION)

This allows the app to identify who is viewing it via `CURRENT_USER()`, enabling audit logging and (future) row-level security.

```sql
USE ROLE ACCOUNTADMIN;

GRANT READ SESSION ON ACCOUNT TO ROLE STREAMLIT_ROLE;
```

### 12.6 Create internal stage for app files

```sql
USE ROLE STREAMLIT_ROLE;
USE WAREHOUSE ETL_WH;

CREATE STAGE IF NOT EXISTS AD_ANALYTICS.GOLD.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit app source files';
```

### 12.7 Upload and deploy the app

Upload files using Snowflake CLI (`snow`) or `PUT`:

```bash
# Option A: Snowflake CLI (recommended)
snow streamlit deploy \
  --database AD_ANALYTICS \
  --schema GOLD \
  --query-warehouse ETL_WH \
  --replace

# Option B: Manual PUT + CREATE STREAMLIT
# Upload files to stage
snow stage copy streamlit_app.py @AD_ANALYTICS.GOLD.STREAMLIT_STAGE/app/ --overwrite
snow stage copy pages/ @AD_ANALYTICS.GOLD.STREAMLIT_STAGE/app/pages/ --overwrite
snow stage copy utils/ @AD_ANALYTICS.GOLD.STREAMLIT_STAGE/app/utils/ --overwrite
snow stage copy environment.yml @AD_ANALYTICS.GOLD.STREAMLIT_STAGE/app/ --overwrite
```

```sql
-- Create the Streamlit app object
USE ROLE STREAMLIT_ROLE;

CREATE OR REPLACE STREAMLIT AD_ANALYTICS.GOLD.AMMODEPOT_DASHBOARD
    FROM '@AD_ANALYTICS.GOLD.STREAMLIT_STAGE/app/'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = 'ETL_WH'
    TITLE = 'Ammunition Depot Analytics';

-- Activate the live version
ALTER STREAMLIT AD_ANALYTICS.GOLD.AMMODEPOT_DASHBOARD ADD LIVE VERSION FROM LAST;
```

### 12.8 Validate

```sql
-- As STREAMLIT_ROLE: verify app exists
USE ROLE STREAMLIT_ROLE;
SHOW STREAMLITS IN SCHEMA AD_ANALYTICS.GOLD;

-- As DASHBOARD_VIEWER_ROLE: verify access
USE ROLE DASHBOARD_VIEWER_ROLE;
SHOW STREAMLITS IN SCHEMA AD_ANALYTICS.GOLD;
-- Should see AMMODEPOT_DASHBOARD

-- Verify viewers cannot access tables directly
USE ROLE DASHBOARD_VIEWER_ROLE;
SELECT COUNT(*) FROM AD_ANALYTICS.GOLD.F_SALES;
-- Expected: error (no SELECT privilege — data is only accessible through the app)
```

### 12.9 App file structure

```
streamlit_app/
├── streamlit_app.py          # Entrypoint (renamed from app.py for SiS convention)
├── pages/
│   ├── today_yesterday.py
│   ├── sales_overview.py
│   └── inventory.py
├── utils/
│   ├── __init__.py
│   └── db.py                 # Dual-mode: get_active_session() in SiS, connector for local dev
└── environment.yml           # Warehouse runtime dependencies (Snowflake Anaconda channel)
```

```yaml
# environment.yml
name: sf_env
channels:
  - snowflake
dependencies:
  - plotly
  - pandas
```

---

## 13. SSO setup (company email authentication)

Snowflake supports SAML 2.0 federated authentication with identity providers (IdP). This allows team members to log into Snowflake — and access the Streamlit dashboard — using their company email.

### 13.1 Choose your identity provider

| Provider | Setup complexity | Notes |
|---|---|---|
| **Google Workspace** | Medium | Create custom SAML app in Admin Console |
| **Microsoft Entra ID** (Azure AD) | Low | Native Snowflake integration in gallery |
| **Okta** | Low | Native Snowflake integration |
| **Any SAML 2.0 IdP** | Medium | Custom configuration |

### 13.2 Create SAML 2.0 security integration

Replace the placeholder values with your IdP's actual SAML metadata.

```sql
USE ROLE ACCOUNTADMIN;

CREATE SECURITY INTEGRATION IF NOT EXISTS AMMODEPOT_AWS_SSO
    TYPE = SAML2
    ENABLED = TRUE
    SAML2_ISSUER = '<your-idp-issuer-url>'
    SAML2_SSO_URL = '<your-idp-sso-url>'
    SAML2_PROVIDER = 'CUSTOM'
    SAML2_X509_CERT = '<base64-encoded-idp-certificate>'
    SAML2_SP_INITIATED_LOGIN_PAGE_LABEL = 'AmmoDepot - AWS SSO'
    SAML2_ENABLE_SP_INITIATED = TRUE
    SAML2_SNOWFLAKE_ISSUER_URL = 'https://iwb48385.us-east-1.snowflakecomputing.com'
    SAML2_SNOWFLAKE_ACS_URL = 'https://iwb48385.us-east-1.snowflakecomputing.com/fed/login'
    SAML2_REQUESTED_NAMEID_FORMAT = 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
    ALLOWED_USER_DOMAINS = ('ammunitiondepot.com');
```

**IdP-specific guides:**
- **Google Workspace**: Admin Console > Apps > Web and mobile apps > Add app > Search "Snowflake"
- **Microsoft Entra ID**: Azure Portal > Enterprise Applications > New > Search "Snowflake"
- **Okta**: Applications > Add Application > Search "Snowflake"

### 13.3 Create SSO users

Each team member who needs dashboard access gets a Snowflake user mapped to their company email. The `TYPE = PERSON` allows interactive login.

```sql
USE ROLE SECURITYADMIN;

-- Example: create a dashboard viewer user
CREATE USER IF NOT EXISTS john_doe
    LOGIN_NAME = 'john.doe@ammodepot.com'
    DISPLAY_NAME = 'John Doe'
    EMAIL = 'john.doe@ammodepot.com'
    DEFAULT_ROLE = DASHBOARD_VIEWER_ROLE
    DEFAULT_WAREHOUSE = ETL_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Dashboard viewer - SSO via company email';

GRANT ROLE DASHBOARD_VIEWER_ROLE TO USER john_doe;
```

**To add multiple users**, repeat the CREATE USER + GRANT ROLE pattern for each team member. Only the `LOGIN_NAME` and `EMAIL` need to match the IdP's SAML assertion.

### 13.4 Validate SSO login

1. Navigate to `https://iwb48385.us-east-1.snowflakecomputing.com`
2. Click "AmmoDepot SSO" on the login page
3. Authenticate with company email via your IdP
4. After login, navigate to **Projects > Streamlit > AMMODEPOT_DASHBOARD**

```sql
-- Verify SSO integration is active
USE ROLE ACCOUNTADMIN;
DESCRIBE SECURITY INTEGRATION AMMODEPOT_SSO;

-- Check user's federated login status
DESCRIBE USER john_doe;
-- Look for HAS_SAML_IDENTITY = TRUE
```

### 13.5 SSO + Streamlit access flow

```text
User (company email)
  │
  ▼
Identity Provider (Google/Azure AD/Okta)
  │ SAML 2.0 assertion
  ▼
Snowflake Login (AMMODEPOT_SSO integration)
  │ Authenticated as john.doe@ammodepot.com
  ▼
DASHBOARD_VIEWER_ROLE role (default)
  │ USAGE on AMMODEPOT_DASHBOARD
  ▼
Streamlit App (runs as STREAMLIT_ROLE — owner's rights)
  │ SELECT on AD_ANALYTICS.GOLD
  ▼
Dashboard data (F_SALES, D_PRODUCT, etc.)
```

---

## 14. Temporary test user (pre-SSO validation)

Before Google SSO is configured, a temporary password-authenticated user allows the client to connect and validate the Streamlit dashboard. **Delete this user once production SSO is live.**

### 14.1 Grant SELECT on GOLD to DASHBOARD_VIEWER_ROLE

In production with SiS, viewers don't need direct table access (the app runs under owner's rights via STREAMLIT_ROLE). However, during the testing phase — especially if running the app locally — the viewer role needs SELECT on GOLD tables.

```sql
USE ROLE SYSADMIN;

-- Temporary: grant SELECT for testing (remove after SiS is deployed and SSO is live)
GRANT SELECT ON ALL TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA AD_ANALYTICS.GOLD TO ROLE DASHBOARD_VIEWER_ROLE;
```

> **Post-SSO cleanup:** Once the app is deployed to SiS and SSO is configured, revoke these SELECT grants. The app will query data through STREAMLIT_ROLE (owner's rights), so viewers only need USAGE on the Streamlit object.
>
> ```sql
> REVOKE SELECT ON ALL TABLES IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
> REVOKE SELECT ON ALL VIEWS IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
> REVOKE SELECT ON FUTURE TABLES IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
> REVOKE SELECT ON FUTURE VIEWS IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
> ```

### 14.2 Create temporary test user

```sql
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS TEMP_USER_DELETE_AFTER_PROD
    PASSWORD = '<strong-password>'
    DEFAULT_ROLE = DASHBOARD_VIEWER_ROLE
    DEFAULT_WAREHOUSE = ETL_WH
    DEFAULT_NAMESPACE = AD_ANALYTICS.GOLD
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Temporary test user for Streamlit validation - DELETE after Google SSO is configured';

GRANT ROLE DASHBOARD_VIEWER_ROLE TO USER TEMP_USER_DELETE_AFTER_PROD;
ALTER USER TEMP_USER_DELETE_AFTER_PROD SET QUERY_TAG = 'temp-dashboard-test';
```

> Change `<strong-password>` before sharing with the client. This user has read-only access to GOLD only — no write privileges, no Silver, no source data.

### 14.3 Validate

```sql
USE ROLE DASHBOARD_VIEWER_ROLE;
USE WAREHOUSE ETL_WH;

-- Verify identity
SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();
-- Expected: TEMP_USER_DELETE_AFTER_PROD, DASHBOARD_VIEWER_ROLE, ETL_WH

-- Verify Gold access
SELECT COUNT(*) FROM AD_ANALYTICS.GOLD.F_SALES;
SELECT COUNT(*) FROM AD_ANALYTICS.GOLD.D_STORE;

-- Verify no access to source schemas
SELECT COUNT(*) FROM AD_AIRBYTE.AD_FISHBOWL.SO;
-- Expected: error (no USAGE on AD_AIRBYTE)

-- Verify no write access
CREATE TABLE AD_ANALYTICS.GOLD._test_write (id INT);
-- Expected: error (no CREATE TABLE privilege)
```

### 14.4 Connection details for the client

| Parameter | Value |
|---|---|
| Account | `iwb48385.us-east-1` |
| Server | `iwb48385.us-east-1.snowflakecomputing.com` |
| User | `TEMP_USER_DELETE_AFTER_PROD` |
| Password | *(shared securely out-of-band)* |
| Role | `DASHBOARD_VIEWER_ROLE` |
| Warehouse | `ETL_WH` |
| Database | `AD_ANALYTICS` |
| Schema | `GOLD` |

### 14.5 Cleanup (after Google SSO is live)

```sql
USE ROLE SECURITYADMIN;

-- Drop temporary user
DROP USER IF EXISTS TEMP_USER_DELETE_AFTER_PROD;

-- Revoke SELECT from DASHBOARD_VIEWER_ROLE (no longer needed with SiS owner's rights)
USE ROLE SYSADMIN;
REVOKE SELECT ON ALL TABLES IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
REVOKE SELECT ON ALL VIEWS IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
REVOKE SELECT ON FUTURE TABLES IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
REVOKE SELECT ON FUTURE VIEWS IN SCHEMA AD_ANALYTICS.GOLD FROM ROLE DASHBOARD_VIEWER_ROLE;
```

---

## Troubleshooting

### "Current role does not have permissions on the target schema"

Airbyte's Snowflake destination checks permissions at three levels. Fix them in order:

| Level | Error message contains | Fix |
|---|---|---|
| Schema | `Schema 'X' already exists, but current role has no privileges` | `GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE AD_AIRBYTE TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;` |
| Table | `Table 'X' already exists, but current role has no privileges` | `GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.<schema> TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;` |
| Stage | Stage/file format permission denied | `GRANT OWNERSHIP ON ALL STAGES IN SCHEMA AD_AIRBYTE."airbyte_internal" TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;` |

**Root cause:** Snowflake's `GRANT OWNERSHIP ON DATABASE` does not cascade to child objects created by other roles. Each level (database → schema → table → stage) needs explicit ownership transfer.

**Quick fix for all levels at once:**

```sql
USE ROLE ACCOUNTADMIN;

-- Database
GRANT OWNERSHIP ON DATABASE AD_AIRBYTE TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;

-- All schemas
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE AD_AIRBYTE TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;

-- All tables in each Airbyte-managed schema
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE."airbyte_internal" TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AD_FISHBOWL TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AD_MAGENTO TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA AD_AIRBYTE.AIRBYTE_SCHEMA TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;

-- All stages in airbyte_internal
GRANT OWNERSHIP ON ALL STAGES IN SCHEMA AD_AIRBYTE."airbyte_internal" TO ROLE AIRBYTE_ROLE COPY CURRENT GRANTS;

-- IMPORTANT: Transfer SILVER/GOLD back to TRANSFORMER_ROLE after bulk grant
GRANT OWNERSHIP ON SCHEMA AD_AIRBYTE.SILVER TO ROLE TRANSFORMER_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA AD_AIRBYTE.GOLD TO ROLE TRANSFORMER_ROLE COPY CURRENT GRANTS;
```

> **Note on `airbyte_internal`:** This is a lowercase, quoted schema (`"airbyte_internal"`) created by Airbyte for raw staging tables, stages, and the `_airbyte_destination_state` table. It is separate from the user-configured Default Schema.
