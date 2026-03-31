# Tag Governance Pattern

> **Purpose**: Standardized Snowflake tag taxonomy for cost attribution, data classification, and operational governance
> **MCP Validated**: 2026-03-30

## When to Use

- Setting up a new Snowflake account or onboarding a new client
- Attributing Snowflake costs by service, client, or environment
- Classifying data for compliance (PII, sensitive, public)
- Enabling tag-based masking policies
- Auditing object ownership and lifecycle

## Tag Taxonomy

### Phase 1: Cost Attribution (implement immediately)

These tags enable answering "who is spending what and why?"

| Tag | Location | Allowed Values | Applied To |
|-----|----------|----------------|------------|
| `service` | `GOVERNANCE.TAGS` | `dbt`, `fivetran`, `airbyte`, `dagster`, `powerbi`, `streamlit`, `ad-hoc` | Warehouses, Users |
| `environment` | `GOVERNANCE.TAGS` | `dev`, `staging`, `prod` | Databases, Schemas |
| `client` | `GOVERNANCE.TAGS` | Client names (e.g., `theraice`, `ammodepot`) | Databases, Warehouses |

### Phase 2: Data Classification (implement when compliance requires)

These tags enable masking policies and access audits.

| Tag | Location | Allowed Values | Applied To |
|-----|----------|----------------|------------|
| `data_class` | `GOVERNANCE.TAGS` | `public`, `internal`, `confidential`, `restricted` | Schemas, Tables, Columns |
| `pii` | `GOVERNANCE.TAGS` | `email`, `phone`, `name`, `address`, `ssn`, `none` | Columns |
| `retention_days` | `GOVERNANCE.TAGS` | Numeric (e.g., `90`, `365`, `indefinite`) | Tables |

### Phase 3: Operational (implement when team > 5)

| Tag | Location | Allowed Values | Applied To |
|-----|----------|----------------|------------|
| `owner` | `GOVERNANCE.TAGS` | Team member names or `unowned` | Databases, Schemas |
| `sla` | `GOVERNANCE.TAGS` | `t+1h`, `t+4h`, `t+24h`, `none` | Schemas (Gold layer) |

## Provisioning SQL

### Infrastructure (run once per account)

```sql
-- SYSADMIN: Create governance database and schema
CREATE DATABASE IF NOT EXISTS GOVERNANCE
    COMMENT = 'Centralized governance objects (tags, policies)';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS
    COMMENT = 'Object tags for cost tracking, ownership, and classification';
```

### Phase 1 Tags (run once per account)

```sql
-- SYSADMIN: Cost attribution tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.service
    ALLOWED_VALUES 'dbt', 'fivetran', 'airbyte', 'dagster', 'powerbi',
                   'streamlit', 'ad-hoc'
    COMMENT = 'Service responsible for this resource cost';

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.environment
    ALLOWED_VALUES 'dev', 'staging', 'prod'
    COMMENT = 'Deployment environment';

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.client
    COMMENT = 'Client name for multi-tenant cost attribution';
    -- No ALLOWED_VALUES — new clients added dynamically
```

### Phase 2 Tags (run when compliance requires)

```sql
-- SYSADMIN: Data classification tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.data_class
    ALLOWED_VALUES 'public', 'internal', 'confidential', 'restricted'
    COMMENT = 'Data classification level per ISO 27001';

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.pii
    ALLOWED_VALUES 'email', 'phone', 'name', 'address', 'ssn', 'none'
    COMMENT = 'PII type for masking policy enforcement';

CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.retention_days
    COMMENT = 'Data retention period in days';
```

## Applying Tags

### Warehouses (Phase 1)

```sql
-- Tag every warehouse with service and client
ALTER WAREHOUSE DBT_TRANSFORMING_WH SET TAG
    GOVERNANCE.TAGS.service = 'dbt',
    GOVERNANCE.TAGS.client = '<client_name>';

ALTER WAREHOUSE INGESTION_WH SET TAG
    GOVERNANCE.TAGS.service = 'fivetran',
    GOVERNANCE.TAGS.client = '<client_name>';

ALTER WAREHOUSE ANALYTICS_WH SET TAG
    GOVERNANCE.TAGS.service = 'powerbi';
```

### Users (Phase 1)

```sql
-- Tag service accounts by service
ALTER USER DBT_TRANSFORMER_USER SET TAG GOVERNANCE.TAGS.service = 'dbt';
ALTER USER SVC_FIVETRAN_USER SET TAG GOVERNANCE.TAGS.service = 'fivetran';
```

### Databases and Schemas (Phase 1)

```sql
-- Tag databases by client and environment
ALTER DATABASE <CLIENT> SET TAG
    GOVERNANCE.TAGS.client = '<client_name>',
    GOVERNANCE.TAGS.environment = 'prod';

ALTER SCHEMA <CLIENT>.DBT_DEV SET TAG GOVERNANCE.TAGS.environment = 'dev';
ALTER SCHEMA <CLIENT>.DBT_PROD_gold SET TAG GOVERNANCE.TAGS.environment = 'prod';
```

### Columns (Phase 2 — classification)

```sql
-- Tag PII columns for masking policy enforcement
ALTER TABLE <client>.DBT_PROD_gold.customers
    MODIFY COLUMN email SET TAG GOVERNANCE.TAGS.pii = 'email';
ALTER TABLE <client>.DBT_PROD_gold.customers
    MODIFY COLUMN phone SET TAG GOVERNANCE.TAGS.pii = 'phone';

-- Tag entire schema by classification
ALTER SCHEMA <client>.DBT_PROD_gold SET TAG
    GOVERNANCE.TAGS.data_class = 'internal';
```

## dbt query_tag Integration

Separate from governance tags, dbt's `query_tag` enables per-model cost attribution
in `snowflake.account_usage.query_history`.

```yaml
# dbt_project.yml — standard query_tag configuration
models:
  my_project:
    +query_tag: "dbt"
    bronze:
      +query_tag: "dbt:bronze"
    silver:
      +query_tag: "dbt:silver"
    gold:
      +query_tag: "dbt:gold"
      intermediate:
        +query_tag: "dbt:gold:intermediate"
```

**Format**: `dbt:{layer}` or `dbt:{layer}:{sublayer}`. Colon-separated for easy `SPLIT_PART` in cost queries.

```sql
-- Cost by dbt layer (last 30 days)
SELECT
    SPLIT_PART(query_tag, ':', 2) AS layer,
    COUNT(*) AS query_count,
    SUM(total_elapsed_time) / 1000 AS total_seconds,
    SUM(credits_used_cloud_services) AS credits
FROM snowflake.account_usage.query_history
WHERE query_tag LIKE 'dbt%'
    AND start_time >= DATEADD(month, -1, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY credits DESC;
```

## Cost Attribution Queries

### Credits by Service (governance tags)

```sql
-- Requires tags applied to warehouses
SELECT
    TAG_VALUE AS service,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3.00, 2) AS estimated_cost_usd
FROM snowflake.account_usage.warehouse_metering_history wmh
JOIN TABLE(
    INFORMATION_SCHEMA.TAG_REFERENCES('GOVERNANCE.TAGS.service', 'WAREHOUSE')
) tr ON wmh.warehouse_name = tr.object_name
WHERE start_time >= DATEADD(month, -1, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2 DESC;
```

### Credits by Client (governance tags)

```sql
SELECT
    TAG_VALUE AS client,
    SUM(credits_used) AS total_credits
FROM snowflake.account_usage.warehouse_metering_history wmh
JOIN TABLE(
    INFORMATION_SCHEMA.TAG_REFERENCES('GOVERNANCE.TAGS.client', 'WAREHOUSE')
) tr ON wmh.warehouse_name = tr.object_name
WHERE start_time >= DATEADD(month, -1, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2 DESC;
```

## Tag-Based Masking Policy (Phase 2)

```sql
-- Create masking policy that reads the PII tag
CREATE MASKING POLICY IF NOT EXISTS GOVERNANCE.TAGS.pii_mask AS
    (val STRING) RETURNS STRING ->
    CASE
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('GOVERNANCE.TAGS.pii') = 'email'
            THEN REGEXP_REPLACE(val, '.+@', '***@')
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('GOVERNANCE.TAGS.pii') = 'phone'
            THEN CONCAT('***-***-', RIGHT(val, 4))
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('GOVERNANCE.TAGS.pii') = 'ssn'
            THEN '***-**-' || RIGHT(val, 4)
        ELSE val
    END;

-- Attach policy to PII tag (applies to ALL tagged columns automatically)
ALTER TAG GOVERNANCE.TAGS.pii SET MASKING POLICY GOVERNANCE.TAGS.pii_mask;
```

## Client Onboarding Tag Checklist

When adding a new client, apply these tags:

- [ ] `ALTER DATABASE <CLIENT> SET TAG GOVERNANCE.TAGS.client = '<name>';`
- [ ] `ALTER DATABASE <CLIENT> SET TAG GOVERNANCE.TAGS.environment = 'prod';`
- [ ] `ALTER SCHEMA <CLIENT>.DBT_DEV SET TAG GOVERNANCE.TAGS.environment = 'dev';`
- [ ] Tag warehouses with `service` and `client`
- [ ] Add `query_tag` to client's `dbt_project.yml`
- [ ] Tag PII columns if classification required (Phase 2)

## Revisit Signals

> 📏 **Phase 2 trigger**: When any client requires SOC2, HIPAA, or GDPR compliance,
> or when an auditor asks "where is PII stored?"

> 📏 **Phase 3 trigger**: When team exceeds 5 people and ownership of schemas
> becomes ambiguous, or when SLA violations need automated alerting.

## See Also

- [rbac-service-accounts.md](rbac-service-accounts.md)
- [rbac-multi-tenant.md](rbac-multi-tenant.md)
- [../concepts/roles-privileges.md](../concepts/roles-privileges.md)
- `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md` (Section 6.3)
- `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md` (Section 5.7)
