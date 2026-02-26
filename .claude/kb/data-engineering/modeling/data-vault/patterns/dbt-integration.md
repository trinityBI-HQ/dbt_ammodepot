# dbt Integration

> **Purpose**: Implementing Data Vault with dbt using AutomateDV and DataVault4dbt
> **MCP Validated**: 2026-02-19

## Packages

| Package | Author | Status | Key Features |
|---------|--------|--------|-------------|
| **AutomateDV** | Datavault Builder | Active, open-source (v0.11.0) | Hubs, Links, Sats, PIT, Bridge, T-Links |
| **DataVault4dbt** | Scalefree (Linstedt) | Active, commercial+OSS | Record Tracking Sats, advanced Effectivity Sats |

## AutomateDV Setup

```yaml
# packages.yml
packages:
  - package: Datavault-UK/automate-dv
    version: [">=0.11.0", "<0.12.0"]
```

### v0.11.0 Changes (May 2025)

- **Composite primary key consistency**: Improved handling of multi-column business keys across all entity macros
- **Incremental load consistency**: More reliable deduplication during incremental runs
- **PIT/Bridge table improvements**: Better snapshot generation and join path computation

```bash
dbt deps
```

## Project Structure

```text
models/
├── staging/                    # Source preparation
│   └── ecommerce/
│       ├── stg_ecommerce__orders.sql
│       └── stg_ecommerce__customers.sql
├── raw_vault/                  # Hubs, Links, Satellites
│   ├── hubs/
│   │   ├── hub_customer.sql
│   │   └── hub_order.sql
│   ├── links/
│   │   └── lnk_customer_order.sql
│   └── satellites/
│       ├── sat_customer_details.sql
│       └── sat_order_details.sql
├── business_vault/             # PIT, Bridge, Business Sats
│   ├── pit_customer.sql
│   └── br_customer_order.sql
└── marts/                      # Star schema presentation
    ├── dim_customers.sql
    └── fct_orders.sql
```

## Staging with AutomateDV

Staging prepares source data with hashed keys using AutomateDV macros:

```sql
-- models/staging/ecommerce/stg_ecommerce__customers.sql
{%- set source_model = "raw_ecommerce_customers" -%}
{%- set derived_columns = {
    "record_source": "!ECOMMERCE",
    "load_date": "CURRENT_TIMESTAMP()"
} -%}
{%- set hashed_columns = {
    "hub_customer_hk": "customer_id",
    "hashdiff_customer_details": {
        "is_hashdiff": true,
        "columns": ["first_name", "last_name", "email", "phone"]
    }
} -%}

{{ automate_dv.stage(
    include_source_columns=true,
    source_model=source_model,
    derived_columns=derived_columns,
    hashed_columns=hashed_columns
) }}
```

## Hub with AutomateDV

```sql
-- models/raw_vault/hubs/hub_customer.sql
{%- set src_pk = "hub_customer_hk" -%}
{%- set src_nk = "customer_id" -%}
{%- set src_ldts = "load_date" -%}
{%- set src_source = "record_source" -%}
{%- set source_model = ref("stg_ecommerce__customers") -%}

{{ automate_dv.hub(
    src_pk=src_pk,
    src_nk=src_nk,
    src_ldts=src_ldts,
    src_source=src_source,
    source_model=source_model
) }}
```

## Link with AutomateDV

```sql
-- models/raw_vault/links/lnk_customer_order.sql
{%- set src_pk = "lnk_customer_order_hk" -%}
{%- set src_fk = ["hub_customer_hk", "hub_order_hk"] -%}
{%- set src_ldts = "load_date" -%}
{%- set src_source = "record_source" -%}
{%- set source_model = ref("stg_ecommerce__orders") -%}

{{ automate_dv.link(
    src_pk=src_pk,
    src_fk=src_fk,
    src_ldts=src_ldts,
    src_source=src_source,
    source_model=source_model
) }}
```

## Satellite with AutomateDV

```sql
-- models/raw_vault/satellites/sat_customer_details.sql
{%- set src_pk = "hub_customer_hk" -%}
{%- set src_hashdiff = "hashdiff_customer_details" -%}
{%- set src_payload = ["first_name", "last_name", "email", "phone"] -%}
{%- set src_ldts = "load_date" -%}
{%- set src_source = "record_source" -%}
{%- set source_model = ref("stg_ecommerce__customers") -%}

{{ automate_dv.sat(
    src_pk=src_pk,
    src_hashdiff=src_hashdiff,
    src_payload=src_payload,
    src_ldts=src_ldts,
    src_source=src_source,
    source_model=source_model
) }}
```

## dbt_project.yml Configuration

```yaml
models:
  my_project:
    staging:
      +materialized: view
    raw_vault:
      +materialized: incremental
      +schema: raw_vault
      hubs:
        +tags: ['hub']
      links:
        +tags: ['link']
      satellites:
        +tags: ['satellite']
    business_vault:
      +materialized: table
      +schema: business_vault
    marts:
      +materialized: table
      +schema: marts
```

## Testing Strategy

| Entity | Required Tests |
|--------|---------------|
| Hub | `unique` + `not_null` on HK and BK |
| Link | `unique` + `not_null` on composite HK; `not_null` on all FK columns |
| Satellite | `unique_combination_of_columns` on (parent_hk, load_date); `relationships` to parent |

## Selective Execution

```bash
dbt run --select tag:hub          # Load all hubs
dbt run --select tag:link         # Load all links
dbt run --select tag:satellite    # Load all satellites
dbt run --select raw_vault+       # Load vault + downstream
dbt build --select marts          # Build marts with tests
```

## See Also

- [loading-patterns.md](loading-patterns.md) — Manual SQL loading patterns
- [business-vault.md](business-vault.md) — PIT and Bridge tables
- [../concepts/hubs.md](../concepts/hubs.md) — Hub entity reference
