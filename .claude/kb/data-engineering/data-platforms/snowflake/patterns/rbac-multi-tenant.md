# RBAC Multi-Tenant Patterns

> **Purpose**: Snowflake RBAC patterns for multi-client data platforms
> **MCP Validated**: 2026-03-30

## When to Use

- Managing multiple clients in a single Snowflake account
- Onboarding a new client to an existing data platform
- Designing client isolation with shared service roles
- Evaluating single-account vs multi-account strategies

## Database-per-Client Model

The standard approach for multi-tenant Snowflake deployments at small-medium scale.

### Architecture

```text
Snowflake Account
├── CLIENT_A (database)          ← Client A analytics
│   ├── DBT_DEV                  ← Dev unified schema
│   ├── DBT_PROD_bronze          ← Prod Bronze layer
│   ├── DBT_PROD_silver          ← Prod Silver layer
│   └── DBT_PROD_gold            ← Prod Gold layer (consumer-facing)
├── CLIENT_B (database)          ← Client B analytics
│   ├── DBT_DEV / DBT_PROD_*    ← Same pattern
├── FIVETRAN_CLIENT_A (database) ← Client A raw ingestion
├── FIVETRAN_CLIENT_B (database) ← Client B raw ingestion
└── GOVERNANCE (database)        ← Tags, audit, cross-client
```

### Shared Roles, Scoped Grants

Service roles are shared (1 dbt role, 1 ingestion role). Access is scoped per client via grants:

```sql
-- dbt can access all clients
GRANT USAGE ON DATABASE CLIENT_A TO ROLE DBT_TRANSFORMER_ROLE;
GRANT USAGE ON DATABASE CLIENT_B TO ROLE DBT_TRANSFORMER_ROLE;

-- Analysts only see their assigned client's Gold
GRANT USAGE ON DATABASE CLIENT_A TO ROLE DATA_ANALYST_ROLE;
GRANT USAGE ON SCHEMA CLIENT_A.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA CLIENT_A.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CLIENT_A.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
-- No grants on CLIENT_B for this analyst
```

### Client Onboarding SQL Template

```sql
-- Step 1: Create client database (SYSADMIN)
CREATE DATABASE IF NOT EXISTS <CLIENT>;

-- Step 2: Create schemas (SYSADMIN)
CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_DEV;
CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_bronze;
CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_silver;
CREATE SCHEMA IF NOT EXISTS <CLIENT>.DBT_PROD_gold;

-- Step 3: Grant dbt source read access (SYSADMIN or ACCOUNTADMIN)
GRANT USAGE ON DATABASE <SOURCE_DB> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT USAGE ON SCHEMA <SOURCE_DB>.<SCHEMA> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA <SOURCE_DB>.<SCHEMA> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <SOURCE_DB>.<SCHEMA> TO ROLE DBT_TRANSFORMER_ROLE;

-- Step 4: Grant dbt write access (SYSADMIN)
-- Repeat for each layer: bronze, silver, gold, DEV
GRANT ALL ON SCHEMA <CLIENT>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON ALL TABLES IN SCHEMA <CLIENT>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON ALL VIEWS IN SCHEMA <CLIENT>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON FUTURE TABLES IN SCHEMA <CLIENT>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;
GRANT ALL ON FUTURE VIEWS IN SCHEMA <CLIENT>.DBT_PROD_bronze TO ROLE DBT_TRANSFORMER_ROLE;

-- Step 5: Grant consumer access to Gold (SYSADMIN)
GRANT USAGE ON DATABASE <CLIENT> TO ROLE DATA_ANALYST_ROLE;
GRANT USAGE ON SCHEMA <CLIENT>.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA <CLIENT>.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <CLIENT>.DBT_PROD_gold TO ROLE DATA_ANALYST_ROLE;

-- Step 6: Tag for cost attribution (SYSADMIN)
ALTER DATABASE <CLIENT> SET TAG GOVERNANCE.TAGS.client = '<client_name>';
```

## When to Use Separate Accounts

| Signal | Single Account | Separate Account |
|--------|---------------|-----------------|
| Same billing entity | Yes | — |
| Different billing per client | — | Yes (Snowflake bills per account) |
| Data residency requirements | — | Yes (account per region) |
| Regulatory isolation (SOC2, HIPAA) | — | Yes |
| Team manages <5 clients | Yes | — |
| Team manages >10 clients | — | Consider |

## Cost Attribution per Client

```sql
-- Tag databases by client for credit allocation
ALTER DATABASE CLIENT_A SET TAG GOVERNANCE.TAGS.client = 'client_a';
ALTER DATABASE CLIENT_B SET TAG GOVERNANCE.TAGS.client = 'client_b';

-- Query cost by client (via warehouse metering + query history)
SELECT
    qh.database_name AS client_database,
    SUM(qh.credits_used_cloud_services) AS credits
FROM snowflake.account_usage.query_history qh
WHERE qh.start_time >= DATEADD(month, -1, CURRENT_TIMESTAMP())
    AND qh.role_name = 'DBT_TRANSFORMER_ROLE'
GROUP BY 1
ORDER BY 2 DESC;
```

## Anti-Pattern: Client-Specific Roles

**Do NOT create per-client service roles** at small scale:

```sql
-- WRONG (at small scale): role sprawl
CREATE ROLE DBT_TRANSFORMER_CLIENT_A_ROLE;
CREATE ROLE DBT_TRANSFORMER_CLIENT_B_ROLE;

-- CORRECT: shared role, scoped via grants
-- DBT_TRANSFORMER_ROLE gets grants for each client database
```

> Revisit when: >10 clients or when different clients need different
> transformation permissions (e.g., one client allows PII access, another doesn't).

## See Also

- [rbac-service-accounts.md](rbac-service-accounts.md)
- [../concepts/roles-privileges.md](../concepts/roles-privileges.md)
- `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md`
