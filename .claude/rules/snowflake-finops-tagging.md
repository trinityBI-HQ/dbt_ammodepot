---
paths:
  - "**/*.sql"
  - "**/*.tf"
  - "**/*.hcl"
  - "**/dbt_project.yml"
  - "**/profiles.yml"
  - "**/WAREHOUSES.md"
  - "**/DATABASES.md"
  - "**/SCHEMAS.md"
  - "**/USERS.md"
---

# FinOps: Snowflake Resource Tagging

> **Principle**: Every Snowflake resource that incurs cost MUST be tagged for attribution. Untagged resources are invisible to FinOps and cannot be allocated to a client or service.

## Mandatory Tags (Phase 1 — Always Required)

Every Snowflake account MUST have these tags in `GOVERNANCE.TAGS`:

| Tag | Applied To | Allowed Values |
|-----|-----------|----------------|
| `service` | Warehouses, Service accounts | `dbt`, `fivetran`, `airbyte`, `dagster`, `powerbi`, `streamlit`, `ad-hoc` |
| `environment` | Databases, Schemas | `dev`, `staging`, `prod` |
| `client` | Databases, Warehouses | Dynamic (client names) |

## Tagging Rules

### When creating or modifying a WAREHOUSE
- MUST include `GOVERNANCE.TAGS.service` tag identifying the workload owner
- MUST include `GOVERNANCE.TAGS.client` tag for cost attribution
- Include tagging SQL in the same file or PR as the warehouse DDL

### When creating or modifying a DATABASE
- MUST include `GOVERNANCE.TAGS.client` tag
- MUST include `GOVERNANCE.TAGS.environment` tag (`dev`, `staging`, `prod`)

### When creating or modifying a SERVICE ACCOUNT (user)
- MUST include `GOVERNANCE.TAGS.service` tag

### When creating or modifying a SCHEMA
- MUST include `GOVERNANCE.TAGS.environment` tag

### dbt Projects
- `dbt_project.yml` MUST configure `query_tag` per medallion layer:
  ```yaml
  models:
    project_name:
      +query_tag: "dbt"
      bronze:
        +query_tag: "dbt:bronze"
      silver:
        +query_tag: "dbt:silver"
      gold:
        +query_tag: "dbt:gold"
  ```
- `query_tag` enables per-layer cost attribution via `snowflake.account_usage.query_history`

### Terraform / IaC
- `snowflake_warehouse` resources MUST include `tag` blocks for `service` and `client`
- `snowflake_database` resources MUST include `tag` blocks for `client` and `environment`
- `snowflake_tag` resources MUST use `ALLOWED_VALUES` (except `client`)
- Tags MUST be defined in the `GOVERNANCE.TAGS` schema, never in analytics schemas

## Tagging SQL Pattern

```sql
-- After creating a warehouse:
ALTER WAREHOUSE <name> SET TAG
    GOVERNANCE.TAGS.service = '<service>',
    GOVERNANCE.TAGS.client  = '<client>';

-- After creating a database:
ALTER DATABASE <name> SET TAG
    GOVERNANCE.TAGS.client      = '<client>',
    GOVERNANCE.TAGS.environment  = '<env>';
```

## Validation

If you generate SQL that creates a warehouse, database, schema, or service account without the corresponding tag statements, add them before presenting the code.

## Cost Attribution Query

Tagged resources enable this FinOps query (credits by service per month):

```sql
SELECT
    TAG_VALUE AS service,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3.00, 2) AS estimated_cost_usd
FROM snowflake.account_usage.warehouse_metering_history wmh
JOIN TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('GOVERNANCE.TAGS.service', 'WAREHOUSE')) tr
    ON wmh.warehouse_name = tr.object_name
WHERE start_time >= DATEADD(month, -1, CURRENT_TIMESTAMP())
GROUP BY 1 ORDER BY 2 DESC;
```

## References

- Full tag taxonomy (Phases 1-3): `.claude/kb/data-engineering/data-platforms/snowflake/patterns/tag-governance.md`
- RBAC & warehouse standards: `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md` (Section 6.3)
- FinOps cost allocation: `.claude/kb/data-engineering/finops/finops/concepts/cost-allocation.md`
- New project onboarding: `.claude/docs/01_NEW_PROJECT_CHECKLIST.md` (Step 1.5)
