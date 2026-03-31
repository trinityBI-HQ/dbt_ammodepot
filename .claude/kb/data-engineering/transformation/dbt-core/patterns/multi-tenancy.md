# Multi-Tenancy Pattern

> **Purpose**: Strategies for serving multiple clients/tenants from a shared dbt codebase
> **MCP Validated**: 2026-03-30

## When to Use

- Serving analytics for multiple clients from one dbt project
- Onboarding a new client to an existing platform
- Need to isolate client data while sharing transformation logic

## Strategy Selection

```text
Need regulatory/compliance isolation?
├── Yes → Database Isolation
└── No
    ├── Different source systems per client?
    │   ├── Yes → Database Isolation
    │   └── No → Schema Isolation
    └── Need cross-tenant analytics?
        ├── Yes → Schema Isolation + aggregation model
        └── No → Either (prefer Database for simplicity)
```

## Database Isolation

Each client gets a dedicated Snowflake database. The dbt project is shared;
client-specific config lives in `dbt_project.yml` or `--vars`.

### Implementation

```text
project_root/
├── clients/
│   ├── client_a/
│   │   └── dbt_project/
│   │       ├── dbt_project.yml     # Client-specific vars, database
│   │       ├── models/             # Client-specific models (if any)
│   │       └── profiles.yml        # Points to client database
│   └── client_b/
│       └── dbt_project/
├── shared/
│   └── dbt_macros/                 # Shared macros (installed via packages)
└── orchestration/                  # Shared orchestration definitions
```

```yaml
# clients/client_a/dbt_project/dbt_project.yml
name: client_a_analytics
profile: client_a

vars:
  source_database: CLIENT_A_RAW
  analytics_database: CLIENT_A_ANALYTICS
  client_name: client_a
```

### Schema Routing (Database Isolation)

```sql
-- shared/dbt_macros/macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'dev' -%}
        {{ target.schema }}
    {%- elif custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name }}
    {%- endif -%}
{%- endmacro %}
```

### Pros and Cons

| Aspect | Database Isolation |
|--------|-------------------|
| Data safety | Strong — no accidental cross-client queries |
| RBAC | Simple — object-level grants per database |
| Snowflake cost | Separate storage per database (no overhead) |
| Maintenance | Higher — deploy to N databases |
| Cross-client analytics | Requires explicit cross-database queries |

## Schema Isolation

Same database, different schemas per client. Routing via dbt variables.

### Implementation

```yaml
# dbt_project.yml
vars:
  client: "{{ env_var('DBT_CLIENT', 'default') }}"

models:
  my_project:
    bronze:
      +schema: "{{ var('client') }}_bronze"
    silver:
      +schema: "{{ var('client') }}_silver"
    gold:
      +schema: "{{ var('client') }}_gold"
```

```bash
# Deploy for client A
DBT_CLIENT=client_a dbt build

# Deploy for client B
DBT_CLIENT=client_b dbt build
```

### Pros and Cons

| Aspect | Schema Isolation |
|--------|-----------------|
| Data safety | Moderate — same database, need careful RBAC |
| RBAC | Requires schema-level grants |
| Snowflake cost | Lower — shared database, shared metadata |
| Maintenance | Lower — single deployment with variable swap |
| Cross-client analytics | Easier — same database |

## Anti-Pattern: tenant_id Column

**Do NOT add `tenant_id` to every table.**

| Problem | Why |
|---------|-----|
| Query complexity | Every query needs `WHERE tenant_id = ...` |
| Security risk | One missing WHERE clause exposes cross-client data |
| Storage overhead | Extra column in every row of every table |
| RBAC complexity | Row-level security instead of object-level grants |
| Performance | Filters on every query, partition overhead |

**Exception**: Only justified for explicit cross-tenant analytics models (e.g., benchmarking aggregations). Even then, build a separate aggregation model rather than threading `tenant_id` through the entire DAG.

## Onboarding a New Client

### Checklist

1. **Provision infrastructure**: Database (or schemas), warehouse, service accounts
2. **Configure sources**: Create `_sources.yml` for client's raw data
3. **Validate source schema**: Ensure source tables match expected structure
4. **Deploy Bronze**: Run `dbt build --select tag:bronze` against new client
5. **Validate Bronze**: Check row counts, null rates, freshness
6. **Deploy Silver+Gold**: Run full `dbt build`
7. **Configure orchestration**: Add client schedule/sensors to orchestrator
8. **Add exposures**: Document client's BI dashboards/APIs
9. **Update CLAUDE.md**: Document new client in project context

## See Also

- [project-structure.md](project-structure.md)
- [best-practices.md](best-practices.md)
- [custom-macros.md](custom-macros.md)
