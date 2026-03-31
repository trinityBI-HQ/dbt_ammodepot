# Section 6: Snowflake RBAC Standards

> **Delivery Standards** — trinityBI Engineering
>
> Last updated: 2026-03-30

---

**Scope**: Universal standards for Snowflake role-based access control across all client accounts. Extracted from the production RBAC manager (snowflake-rbac-manager) and validated against 2 production dbt projects. Designed for a small team (2-4 people) managing 2-5 Snowflake accounts.

**Relationship to other standards:**
- **dbt conventions**: See `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md` (multi-tenancy in 5.6, costs in 5.7)
- **SQL formatting**: See `.claude/rules/sql-standards.md`
- **Snowflake KB**: See `.claude/kb/data-engineering/data-platforms/snowflake/`

---

## 6.1 Role Hierarchy Design

### Standard Role Taxonomy

#### Classification: 🔒 Universal

Every Snowflake account must implement this role hierarchy:

```text
ACCOUNTADMIN (Snowflake built-in — account owner)
    └── SYSADMIN (Snowflake built-in — owns all data objects)
        ├── Service Roles (programmatic access)
        │   ├── DBT_TRANSFORMER_ROLE      — dbt read sources + write transforms
        │   ├── INGESTION_ROLE            — Fivetran/Airbyte write to raw
        │   └── ORCHESTRATOR_ROLE         — Dagster/Airflow read streams + trigger builds
        │
        └── Team Roles (human access)
            ├── DATA_ENGINEER_ROLE        — full dev, read prod
            ├── DATA_ANALYST_ROLE         — read Gold only
            ├── BI_DEVELOPER_ROLE         — read Gold, create dashboards
            ├── DATA_SCIENTIST_ROLE       — read Gold, write sandbox
            └── BUSINESS_USER_ROLE        — read curated Gold views
```

**Critical rule**: All custom roles must be granted TO SYSADMIN:

```sql
GRANT ROLE DBT_TRANSFORMER_ROLE TO ROLE SYSADMIN;
GRANT ROLE INGESTION_ROLE       TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER_ROLE   TO ROLE SYSADMIN;
-- ... repeat for all custom roles
```

**Why**: If custom roles are not in the SYSADMIN hierarchy, SYSADMIN cannot manage objects owned by those roles. This creates orphaned objects that only ACCOUNTADMIN can fix.

> **Evidence**: snowflake-rbac-manager grants all 7 custom roles to SYSADMIN (GRANTS.md Section 1).

### System Role Usage

#### Classification: 🔒 Universal

| Role | Use For | Never Use For |
|------|---------|---------------|
| **ACCOUNTADMIN** | SSO/SAML setup, cross-database grants, security integrations | Daily work, queries, dbt runs |
| **SECURITYADMIN** | CREATE ROLE, GRANT ROLE, ALTER USER (RSA keys) | Data queries, schema changes |
| **USERADMIN** | CREATE USER, ALTER USER properties | Grants, data access |
| **SYSADMIN** | CREATE WAREHOUSE/DATABASE/SCHEMA/STREAM, object grants | User management, security integrations |

**Rule**: No team member's default role should be a system role. System roles are for provisioning only.

```sql
-- CORRECT: Team member gets a custom role as default
ALTER USER victor_snowflake SET DEFAULT_ROLE = DATA_ENGINEER_ROLE;

-- WRONG: Team member defaults to SYSADMIN
ALTER USER victor_snowflake SET DEFAULT_ROLE = SYSADMIN;
```

> 📏 **Revisit signal**: When team grows beyond 10 people, consider adding domain-scoped roles (e.g., `DATA_ENGINEER_SALES_ROLE`, `DATA_ENGINEER_INVENTORY_ROLE`).

### Team Role Permissions Matrix

#### Classification: 🔒 Universal

| Permission | DATA_ENGINEER | DATA_ANALYST | BI_DEVELOPER | DATA_SCIENTIST | BUSINESS_USER |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Dev schemas (read/write) | Yes | — | — | — | — |
| Prod Bronze (read) | Yes | — | — | — | — |
| Prod Silver (read) | Yes | — | — | — | — |
| Prod Gold (read) | Yes | Yes | Yes | Yes | Yes |
| Sandbox (write) | — | — | — | Yes | — |
| Create views/tables in dev | Yes | — | — | — | — |
| Warehouse (run queries) | Yes | Yes | Yes | Yes | Yes |

**Principle**: Everyone can read Gold. Only engineers write to dev. Only data scientists get a sandbox. Nobody reads Bronze/Silver except engineers and service accounts.

---

## 6.2 Service Account Patterns

### Naming Convention

#### Classification: 🔒 Universal

| Object | Convention | Example |
|--------|-----------|---------|
| Service user | `SVC_{TOOL}_USER` or `{TOOL}_USER` | `SVC_FIVETRAN_USER`, `DBT_TRANSFORMER_USER` |
| Service role | `{TOOL}_{PURPOSE}_ROLE` | `DBT_TRANSFORMER_ROLE`, `INGESTION_ROLE` |
| Team user | `{firstname}_snowflake` | `victor_snowflake`, `daniel_snowflake` |
| Team role | `{FUNCTION}_ROLE` | `DATA_ENGINEER_ROLE`, `DATA_ANALYST_ROLE` |

### Standard Service Accounts

#### Classification: 📐 Pattern (condition: modern data stack with dbt + ingestion tool)

**1. dbt Transformer**

```sql
-- USERADMIN
CREATE USER IF NOT EXISTS DBT_TRANSFORMER_USER
    PASSWORD = '<from_secret_manager>'
    LOGIN_NAME = 'DBT_TRANSFORMER_USER'
    DISPLAY_NAME = 'dbt Transformer Service Account'
    DEFAULT_ROLE = DBT_TRANSFORMER_ROLE
    DEFAULT_WAREHOUSE = DBT_TRANSFORMING_WH
    DEFAULT_NAMESPACE = '<CLIENT>.DBT_DEV'
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Service account for dbt transformations via Dagster/CI';
```

**Permissions**: Read all source schemas + write all dbt output schemas (dev + prod layers).

**2. Ingestion Service (Fivetran/Airbyte)**

```sql
-- USERADMIN
CREATE USER IF NOT EXISTS SVC_FIVETRAN_USER
    LOGIN_NAME = 'SVC_FIVETRAN_USER'
    DISPLAY_NAME = 'Fivetran Ingestion Service Account'
    DEFAULT_ROLE = INGESTION_ROLE
    DEFAULT_WAREHOUSE = INGESTION_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Service account for Fivetran data ingestion';

-- No password — key pair auth only
```

**Permissions**: Write to destination databases only. No read access to analytics schemas. CREATE SCHEMA on destination databases (Fivetran creates schemas dynamically).

**3. Orchestrator (optional — when orchestrator needs direct Snowflake access)**

Only needed when the orchestrator reads Snowflake streams directly (e.g., Dagster CDC sensors).

```sql
-- Permissions: SELECT on streams + INSERT on audit log table
GRANT SELECT ON ALL STREAMS IN SCHEMA <CLIENT>.<SCHEMA> TO ROLE ORCHESTRATOR_ROLE;
GRANT INSERT, SELECT ON TABLE <CLIENT>.DBT_PROD_bronze._DAGSTER_STREAM_LOG TO ROLE ORCHESTRATOR_ROLE;
```

> **Evidence**: In snowflake-rbac-manager, the dbt transformer role also reads streams. For larger deployments, separating orchestrator from transformer prevents privilege creep.

### Authentication

#### Classification: 🔒 Universal

| Account Type | Auth Method | Why |
|-------------|-------------|-----|
| Service accounts | RSA key pair (2048-bit) | No password rotation needed; revocable; CI/CD-friendly |
| Team members | SSO (SAML2) + password fallback | Centralized identity; MFA via IdP |
| Emergency access | Password (ACCOUNTADMIN only) | Break-glass; stored in password manager |

**Key pair setup**:

```bash
# Generate RSA key pair (2048-bit, PKCS#8, no encryption for CI/CD)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

```sql
-- Register public key (SECURITYADMIN)
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY = '<base64_public_key_body>';
```

**Key rotation** (zero-downtime):
```sql
-- Step 1: Set new key as RSA_PUBLIC_KEY_2
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY_2 = '<new_public_key>';
-- Step 2: Update CI/CD to use new private key
-- Step 3: Rotate primary key
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY = '<new_public_key>';
ALTER USER DBT_TRANSFORMER_USER UNSET RSA_PUBLIC_KEY_2;
```

> **Evidence**: snowflake-rbac-manager documents this exact pattern in KEY_PAIR_AUTH.md. SVC_FIVETRAN_USER uses key pair exclusively (no password).

### Secret Storage

#### Classification: 🔒 Universal

| Secret | Where to Store | Never Store In |
|--------|---------------|----------------|
| RSA private key | AWS Secrets Manager, GCP Secret Manager, or 1Password | Git repo, environment variables as plaintext, dbt profiles.yml |
| Snowflake password | Password manager (1Password) | Code, CI/CD config, CLAUDE.md |
| Connection strings | Environment variables (loaded from secret manager) | Committed files |

---

## 6.3 Warehouse Access Patterns

### Warehouse Design

#### Classification: 🔒 Universal

| Warehouse | Size | Auto-Suspend | Purpose | Assigned Roles |
|-----------|------|-------------|---------|----------------|
| `DBT_TRANSFORMING_WH` | X-Small | 60s | dbt builds (dev + prod) | DBT_TRANSFORMER_ROLE |
| `INGESTION_WH` | X-Small | 60s | Fivetran/Airbyte COPY INTO | INGESTION_ROLE |
| `ANALYTICS_WH` | X-Small | 60s | BI queries, analyst ad-hoc | DATA_ANALYST_ROLE, BI_DEVELOPER_ROLE, BUSINESS_USER_ROLE |
| `ENGINEERING_WH` | X-Small | 60s | Engineer ad-hoc queries | DATA_ENGINEER_ROLE, DATA_SCIENTIST_ROLE |

**Rules**:
1. **Start X-Small for everything**. Snowflake's elastic compute means XS handles most dbt workloads.
2. **One warehouse per workload type**, not per user. Prevents idle warehouse sprawl.
3. **Auto-suspend at 60 seconds**. No exceptions unless you have sub-second latency requirements.
4. **Auto-resume enabled** on all warehouses.
5. **Separate ingestion from transformation**. Prevents contention between COPY INTO and dbt SELECT queries.

```sql
-- SYSADMIN
CREATE WAREHOUSE IF NOT EXISTS DBT_TRANSFORMING_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'dbt transformation compute';
```

**Grant pattern**:
```sql
-- Ingestion role gets USAGE + OPERATE (can suspend/resume for cost control)
GRANT USAGE   ON WAREHOUSE INGESTION_WH TO ROLE INGESTION_ROLE;
GRANT OPERATE ON WAREHOUSE INGESTION_WH TO ROLE INGESTION_ROLE;

-- All other roles get USAGE only
GRANT USAGE ON WAREHOUSE DBT_TRANSFORMING_WH TO ROLE DBT_TRANSFORMER_ROLE;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ANALYST_ROLE;
```

> **Evidence**: snowflake-rbac-manager uses exactly this pattern — X-Small with 60s auto-suspend. FIVETRAN_INGESTION_ROLE gets OPERATE; DBT_TRANSFORMER_ROLE gets USAGE only.

> 📏 **Revisit signal**: Upgrade from X-Small when Snowflake query history shows >50% of dbt queries queuing (waiting for compute). Use `query_tag` data to identify which warehouse needs scaling.

### Cost Attribution via Tags

#### Classification: 🔒 Universal

Every warehouse, service account, and database must be tagged for cost attribution. The full tag taxonomy, provisioning SQL, and cost queries are in the dedicated pattern file:

> **Full reference**: `.claude/kb/data-engineering/data-platforms/snowflake/patterns/tag-governance.md`

**Minimum tags (Phase 1)**:

| Tag | Applied To | Purpose |
|-----|-----------|---------|
| `GOVERNANCE.TAGS.service` | Warehouses, Users | Who is spending (dbt, fivetran, powerbi) |
| `GOVERNANCE.TAGS.environment` | Databases, Schemas | Dev vs prod cost split |
| `GOVERNANCE.TAGS.client` | Databases, Warehouses | Per-client cost attribution |

**dbt query_tag** (complementary — works alongside governance tags):

```yaml
# dbt_project.yml — required for all projects
models:
  my_project:
    +query_tag: "dbt"
    bronze:
      +query_tag: "dbt:bronze"
    silver:
      +query_tag: "dbt:silver"
    gold:
      +query_tag: "dbt:gold"
```

---

## 6.4 Grant Patterns

### The Grant Cascade

#### Classification: 🔒 Universal

Every schema access follows this 4-statement cascade:

```sql
-- 1. Database access
GRANT USAGE ON DATABASE <database> TO ROLE <role>;

-- 2. Schema access
GRANT USAGE ON SCHEMA <database>.<schema> TO ROLE <role>;

-- 3. Current objects
GRANT SELECT ON ALL TABLES IN SCHEMA <database>.<schema> TO ROLE <role>;

-- 4. Future objects (critical — without this, new tables are invisible)
GRANT SELECT ON FUTURE TABLES IN SCHEMA <database>.<schema> TO ROLE <role>;
```

**Why all 4 are required**: Missing any one causes silent access failures. Missing FUTURE grants is the most common mistake — the role works today but breaks when a new table is created.

### Read vs Write Grant Templates

#### Classification: 🔒 Universal

**READ access** (for consumer roles accessing Gold):
```sql
GRANT USAGE ON DATABASE <client> TO ROLE <consumer_role>;
GRANT USAGE ON SCHEMA <client>.DBT_PROD_gold TO ROLE <consumer_role>;
GRANT SELECT ON ALL TABLES IN SCHEMA <client>.DBT_PROD_gold TO ROLE <consumer_role>;
GRANT SELECT ON ALL VIEWS IN SCHEMA <client>.DBT_PROD_gold TO ROLE <consumer_role>;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <client>.DBT_PROD_gold TO ROLE <consumer_role>;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA <client>.DBT_PROD_gold TO ROLE <consumer_role>;
```

**WRITE access** (for dbt output schemas):
```sql
GRANT ALL ON SCHEMA <client>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON ALL TABLES IN SCHEMA <client>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON ALL VIEWS IN SCHEMA <client>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON FUTURE TABLES IN SCHEMA <client>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON FUTURE VIEWS IN SCHEMA <client>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
-- Repeat for silver, gold schemas
```

**INGESTION access** (for Fivetran/Airbyte destination databases):
```sql
GRANT USAGE ON DATABASE <fivetran_db> TO ROLE INGESTION_ROLE;
GRANT CREATE SCHEMA ON DATABASE <fivetran_db> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE <fivetran_db> TO ROLE INGESTION_ROLE;
-- Per-schema grants for existing schemas
GRANT ALL PRIVILEGES ON SCHEMA <fivetran_db>.<schema> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA <fivetran_db>.<schema> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA <fivetran_db>.<schema> TO ROLE INGESTION_ROLE;
```

### Ownership Transfer

#### Classification: 📐 Pattern (condition: objects created by ACCOUNTADMIN that need role ownership)

```sql
-- Transfer ownership of pre-existing objects to the correct role
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA <db>.<schema>
    TO ROLE INGESTION_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL VIEWS IN SCHEMA <db>.<schema>
    TO ROLE INGESTION_ROLE COPY CURRENT GRANTS;
```

**Why**: When ACCOUNTADMIN creates objects manually (e.g., initial setup), the owning role is ACCOUNTADMIN. Service roles cannot modify objects they don't own. `COPY CURRENT GRANTS` preserves existing access.

### Execution Order

#### Classification: 🔒 Universal

RBAC SQL must be executed in this order to avoid dependency errors:

```text
1. ROLES      (SECURITYADMIN)   — Create roles
2. USERS      (USERADMIN)       — Create users
3. WAREHOUSES (SYSADMIN)        — Create warehouses
4. SCHEMAS    (SYSADMIN)        — Create schemas
5. STREAMS    (SYSADMIN)        — Create streams (if CDC)
6. GRANTS     (Multi-role)      — All privilege assignments
7. KEY AUTH   (SECURITYADMIN)   — RSA key registration
```

**Why**: Grants reference roles, users, warehouses, and schemas. Creating them first prevents "object does not exist" errors.

> **Evidence**: snowflake-rbac-manager documents this exact 7-step sequence in README.md.

---

## 6.5 Multi-Tenant RBAC

### Database-per-Client Model

#### Classification: 📐 Pattern (condition: multi-client deployments)

Each client gets a dedicated database. Service roles are shared but granted per-client database access:

```text
Account
├── CLIENT_A (database)
│   ├── DBT_DEV          — dev unified schema
│   ├── DBT_PROD_bronze  — prod Bronze
│   ├── DBT_PROD_silver  — prod Silver
│   └── DBT_PROD_gold    — prod Gold
├── CLIENT_B (database)
│   ├── DBT_DEV
│   ├── DBT_PROD_bronze
│   ├── DBT_PROD_silver
│   └── DBT_PROD_gold
├── FIVETRAN_CLIENT_A (database) — ingestion destination
├── FIVETRAN_CLIENT_B (database)
└── GOVERNANCE (database) — tags, audit
```

**Shared roles, scoped access**:
```sql
-- DBT_TRANSFORMER_ROLE can access both clients
GRANT USAGE ON DATABASE CLIENT_A TO ROLE DBT_TRANSFORMER_ROLE;
GRANT USAGE ON DATABASE CLIENT_B TO ROLE DBT_TRANSFORMER_ROLE;

-- Analysts see only their client's Gold
GRANT USAGE ON DATABASE CLIENT_A TO ROLE DATA_ANALYST_ROLE;
GRANT USAGE ON SCHEMA CLIENT_A.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
-- CLIENT_B Gold NOT granted to analyst role
```

### Client Onboarding Checklist

#### Classification: 🔒 Universal

When adding a new client to an existing Snowflake account:

1. **Create database**: `CREATE DATABASE IF NOT EXISTS <CLIENT>;`
2. **Create schemas** (dev + prod layers):
   ```sql
   CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_DEV;
   CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_bronze;
   CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_silver;
   CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_gold;
   ```
3. **Grant dbt access**: Full cascade for source read + output write
4. **Grant ingestion access**: If separate Fivetran/Airbyte database
5. **Grant consumer access**: Analyst/BI roles to Gold only
6. **Create streams** (if using CDC sensors)
7. **Tag objects** for cost attribution
8. **Verify**: Run `SHOW GRANTS TO ROLE <role>` smoke tests
9. **Document**: Update RBAC manager files (SCHEMAS.md, GRANTS.md)

> **Evidence**: snowflake-rbac-manager documents this onboarding flow in README.md "Adding a New Client" section.

### When to Use Separate Accounts

#### Classification: 📐 Pattern (condition: regulatory or billing isolation)

| Signal | Action |
|--------|--------|
| Regulatory requirement for data isolation | Separate Snowflake account per client |
| Different billing/invoicing per client | Separate account (Snowflake bills per account) |
| Different geographic regions (data residency) | Separate account in correct region |
| Simple multi-tenancy, same billing | Same account, database isolation |

> 📏 **Revisit signal**: When managing >5 clients in a single account, evaluate whether account-level separation simplifies RBAC and billing.

---

## 6.6 SSO and Enterprise Authentication

### SAML2 Integration (AWS IAM Identity Center)

#### Classification: 📐 Pattern (condition: team >3 people or compliance requirement)

```sql
-- ACCOUNTADMIN
CREATE SECURITY INTEGRATION IF NOT EXISTS aws_iam_identity_center
    TYPE = SAML2
    ENABLED = TRUE
    SAML2_ISSUER = '<issuer_url>'
    SAML2_SSO_URL = '<sso_url>'
    SAML2_PROVIDER = 'CUSTOM'
    SAML2_X509_CERT = '<certificate>'
    SAML2_SP_INITIATED_LOGIN_PAGE_LABEL = 'AWS IAM Identity Center'
    SAML2_ENABLE_SP_INITIATED = TRUE
    SAML2_SNOWFLAKE_ISSUER_URL = 'https://<account>.snowflakecomputing.com'
    SAML2_SNOWFLAKE_ACS_URL = 'https://<account>.snowflakecomputing.com/fed/login';
```

**User provisioning with SSO**:
```sql
-- LOGIN_NAME must match the email attribute from the IdP
CREATE USER IF NOT EXISTS victor_snowflake
    LOGIN_NAME = 'victor@company.com'
    DISPLAY_NAME = 'Victor'
    DEFAULT_ROLE = DATA_ENGINEER_ROLE
    DEFAULT_WAREHOUSE = ENGINEERING_WH;
```

> **Evidence**: snowflake-rbac-manager includes `snowflake_aws_sso_guide.md` with complete AWS IAM Identity Center → Snowflake SAML2 configuration.

> 📏 **Revisit signal**: Implement SSO when team exceeds 3 people or when a compliance audit requires centralized identity management.

---

## 6.7 Streams and CDC Access

### Stream Patterns

#### Classification: 📐 Pattern (condition: event-driven orchestration with Dagster/Airflow)

```sql
-- SYSADMIN: Create streams for CDC event detection
CREATE STREAM IF NOT EXISTS <CLIENT>.<SCHEMA>.DAGSTER_STREAM__<TABLE>
    ON TABLE <CLIENT>.<SCHEMA>.<TABLE>
    APPEND_ONLY = TRUE    -- Use for insert-only tables (logs, events)
    SHOW_INITIAL_ROWS = FALSE;

-- Standard mode for tables with updates
CREATE STREAM IF NOT EXISTS <CLIENT>.<SCHEMA>.DAGSTER_STREAM__<TABLE>
    ON TABLE <CLIENT>.<SCHEMA>.<TABLE>
    SHOW_INITIAL_ROWS = FALSE;
```

**Stream naming**: `DAGSTER_STREAM__<TABLE_NAME>` (double underscore separator, matching dbt source naming convention).

**Stream audit log**:
```sql
-- Track when streams are consumed (audit trail)
CREATE TABLE IF NOT EXISTS <CLIENT>.DBT_PROD_bronze._DAGSTER_STREAM_LOG (
    stream_name   VARCHAR(256)    NOT NULL,
    detected_at   TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    row_count     NUMBER          NOT NULL
);

-- Grant orchestrator INSERT + SELECT
GRANT INSERT, SELECT ON TABLE <CLIENT>.DBT_PROD_bronze._DAGSTER_STREAM_LOG
    TO ROLE DBT_TRANSFORMER_ROLE;
```

**Stream mode decision**:
| Source Behavior | Stream Mode | Why |
|----------------|------------|-----|
| Insert-only (logs, events, orders) | `APPEND_ONLY = TRUE` | Lower overhead, no UPDATE tracking |
| Updates + deletes (inventory, status) | Standard (default) | Captures all DML changes |

> **Evidence**: snowflake-rbac-manager defines 6 streams: 4 APPEND_ONLY (orders, retail sales) + 2 Standard (inventory, calendar).

---

## 6.8 Provisioning Approach

### Manual SQL with Documentation

#### Classification: 📐 Pattern (condition: <5 Snowflake accounts)

**Current standard**: One SQL documentation file per object type, executed in order.

```text
snowflake-rbac-manager/
├── README.md              — Architecture, execution order, onboarding
├── ROLES.md               — Role creation (SECURITYADMIN)
├── USERS.md               — User creation (USERADMIN)
├── WAREHOUSES.md          — Warehouse creation (SYSADMIN)
├── SCHEMAS.md             — Schema creation (SYSADMIN)
├── STREAMS.md             — Stream creation (SYSADMIN)
├── GRANTS.md              — All privilege grants (multi-role)
├── KEY_PAIR_AUTH.md        — RSA key setup (SECURITYADMIN)
└── snowflake_aws_sso_guide.md — SAML2 SSO config (ACCOUNTADMIN)
```

**Rules for provisioning SQL**:
1. **Idempotent**: All statements use `CREATE IF NOT EXISTS` or `CREATE OR REPLACE`
2. **Execution role documented**: Each file declares the Snowflake role required to execute
3. **One object type per file**: No mixing roles and grants in the same file
4. **Comments for every grant**: Explain why the access is needed

**Verification after provisioning**:
```sql
-- Smoke test: verify role grants
USE ROLE ACCOUNTADMIN;
SHOW GRANTS TO ROLE DBT_TRANSFORMER_ROLE;
SHOW GRANTS TO ROLE INGESTION_ROLE;

-- Functional test: verify dbt can read sources
USE ROLE DBT_TRANSFORMER_ROLE;
SELECT COUNT(*) FROM <source_database>.<schema>.<table>;

-- Functional test: verify analysts can read Gold
USE ROLE DATA_ANALYST_ROLE;
SELECT COUNT(*) FROM <client>.DBT_PROD_gold.<table>;
```

### When to Automate

> 📏 **Revisit signal**: Move to Terraform/Pulumi when:
> - Managing >5 Snowflake accounts
> - Team >5 people making RBAC changes
> - Compliance requires audit trail of every RBAC change (git history is sufficient today)
> - Provisioning a new client takes >2 hours manually

**Terraform provider**: `Snowflake-Labs/snowflake` (official). When ready, the SQL files become the spec for Terraform resources — same logical structure, different execution mechanism.

---

## 6.9 Anti-Patterns

#### Classification: 🔒 Universal (all items)

| # | Anti-Pattern | Why It's Bad | Do Instead |
|---|-------------|-------------|------------|
| 1 | **Using ACCOUNTADMIN as default role** | Bypasses all privilege checks; accidental DDL affects everything | Custom role per user function; ACCOUNTADMIN only for provisioning |
| 2 | **Granting to PUBLIC role** | Every user and service account inherits the grant | Create specific roles for each access level |
| 3 | **Missing FUTURE grants** | New tables/views are invisible to existing roles | Always include GRANT ... ON FUTURE TABLES/VIEWS |
| 4 | **One warehouse for everything** | Contention between ingestion, transformation, and queries; impossible to attribute costs | Separate warehouses by workload type |
| 5 | **Password auth for service accounts** | Passwords require rotation; vulnerable to credential leaks | RSA key pair authentication exclusively |
| 6 | **Sharing ACCOUNTADMIN credentials** | No audit trail; single point of failure | Each admin uses personal login; break-glass password in vault |
| 7 | **GRANT ALL ON DATABASE** | Grants excessive privileges including CREATE SCHEMA, DROP | Grant specific privileges: USAGE + SELECT per schema |
| 8 | **No role hierarchy to SYSADMIN** | Orphaned objects; SYSADMIN cannot manage role's objects | All custom roles granted TO SYSADMIN |
| 9 | **Hard-coding account/database names in grants** | Not portable across clients/environments | Use variables or templated SQL per client |
| 10 | **Skipping ownership transfer** | Objects created by ACCOUNTADMIN cannot be managed by service roles | `GRANT OWNERSHIP ... COPY CURRENT GRANTS` |

### Detailed Anti-Pattern: Missing FUTURE Grants

> ⚠️ **Most common RBAC failure mode**

**Symptom**: "I can see the old tables but not the new ones that Fivetran just loaded."

**Root cause**: Grants were applied with `ON ALL TABLES` but not `ON FUTURE TABLES`.

```sql
-- WRONG: Works today, breaks tomorrow
GRANT SELECT ON ALL TABLES IN SCHEMA raw.orders TO ROLE DATA_ANALYST_ROLE;

-- CORRECT: Works today and forever
GRANT SELECT ON ALL TABLES IN SCHEMA raw.orders TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA raw.orders TO ROLE DATA_ANALYST_ROLE;
```

---

## 6.10 Active Technical Debt

> **Living registry** — update when debt is created or resolved. Last reviewed: 2026-03-30.

### 🟡 Important

| # | Debt | Where | Impact | Remediation |
|---|------|-------|--------|-------------|
| 1 | **Legacy Apothca warehouse** — `FIVETRAN_WH_APOTHCA` still exists | snowflake-rbac-manager WAREHOUSES.md | Extra idle warehouse; cost leak | Migrate connectors to INGESTION_WH; drop legacy WH |
| 2 | **User naming inconsistency** — `daniel_snowflake` in grants vs `danielscapol` as actual user | snowflake-rbac-manager GRANTS.md line 40 | Grant silently fails (user doesn't exist) | Fix grant to use actual username |
| 3 | **No GOVERNANCE tags populated** — Schema exists but no tags applied | snowflake-rbac-manager SCHEMAS.md | Cannot attribute costs by service/client | Apply tags to all warehouses and service accounts |
| 4 | **MANAGE GRANTS on SYSADMIN** — Broad permission for convenience | snowflake-rbac-manager GRANTS.md | SYSADMIN can modify any grant, not just its own objects | Evaluate removing; use ACCOUNTADMIN for cross-ownership grants |

### 🟢 Minor

| # | Debt | Where | Impact | Remediation |
|---|------|-------|--------|-------------|
| 5 | **No SSO enforced** — SSO configured but password fallback still active | snowflake-rbac-manager USERS.md | Users can bypass SSO with direct password login | Set `MUST_USE_MULTI_FACTOR_AUTHENTICATION = TRUE` after SSO rollout |
| 6 | **Orchestrator role not separated** — dbt role reads streams | snowflake-rbac-manager GRANTS.md | dbt role has broader permissions than needed | Create separate ORCHESTRATOR_ROLE for stream access |

---

## 6.11 Action Plan (2 Weeks)

| Wk | # | Action | Effort | Impact |
|----|---|--------|--------|--------|
| 1 | 1 | Fix user naming inconsistency (danielscapol) | 5 min | Prevents silent grant failure |
| 1 | 2 | Populate GOVERNANCE tags on all warehouses and service accounts | 1h | Enables cost attribution |
| 1 | 3 | Migrate Apothca connectors to INGESTION_WH; drop legacy WH | 2h | Eliminates idle cost |
| 2 | 4 | Evaluate removing MANAGE GRANTS from SYSADMIN | 1h | Tighten least privilege |
| 2 | 5 | Create ORCHESTRATOR_ROLE, separate stream access from dbt | 2h | Cleaner privilege boundary |
| 2 | 6 | Enable MFA enforcement after confirming SSO works for all users | 1h | Compliance posture |

---

*Built from evidence in snowflake-rbac-manager (1 production Snowflake account, 7 roles, 7 users, 3 warehouses, 6 streams). Every pattern has a real-world justification.*
