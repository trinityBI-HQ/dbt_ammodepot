# dbt Mesh Pattern

> **Purpose**: Multi-project architecture with cross-project references and governance (stable)
> **MCP Validated**: 2026-02-19

## When to Use

dbt Mesh is now **stable** in dbt Cloud and provides production-ready multi-project
governance with cross-project lineage visible in dbt Explorer.

- Large organizations with multiple data domains
- Need clear ownership boundaries between teams
- Want to share stable interfaces between projects
- Implementing data mesh principles with dbt
- Need cross-project lineage tracking in dbt Explorer

## Implementation

### Project Dependencies

```yaml
# dbt_project.yml (downstream project)
name: marketing_analytics

# dependencies.yml
projects:
  - name: core_data
    # Reference models from core_data project
```

### Cross-Project References

```sql
-- models/marts/marketing/fct_campaigns.sql
-- Reference public model from another project

select
    c.campaign_id,
    c.campaign_name,
    o.order_count,
    o.revenue
from {{ ref('stg_campaigns') }} c
left join {{ ref('core_data', 'fct_orders') }} o
    on c.campaign_id = o.campaign_id
```

### Model Contracts

```yaml
# models/marts/_models.yml (core_data project)
models:
  - name: fct_orders
    description: "Stable orders interface for downstream projects"
    access: public
    group: core_analytics
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: integer
        constraints:
          - type: not_null
          - type: primary_key
      - name: customer_id
        data_type: integer
      - name: order_date
        data_type: date
      - name: total_amount
        data_type: numeric
```

### Access Modifiers

```yaml
models:
  - name: fct_orders
    access: public      # Referenceable by other projects

  - name: int_orders_enriched
    access: protected   # Only within same group

  - name: stg_orders_raw
    access: private     # Only within same project
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `access` | protected | public, protected, private |
| `group` | None | Logical grouping for access control |
| `contract.enforced` | false | Enforce column types/constraints |

## Model Versioning

```yaml
models:
  - name: dim_customers
    access: public
    versions:
      - v: 1
        config:
          alias: dim_customers_v1
      - v: 2
        columns:
          - include: '*'
          - name: segment  # New column in v2
```

```sql
-- Reference specific version
select * from {{ ref('core_data', 'dim_customers', v=1) }}
```

## Semantic Layer Integration

```yaml
# Semantic models can reference cross-project
semantic_models:
  - name: orders
    model: ref('core_data', 'fct_orders')
    entities:
      - name: order
        type: primary
        expr: order_id
    measures:
      - name: total_revenue
        agg: sum
        expr: total_amount
```

## Project Structure

```
organization/
├── core_data/              # Foundational data
│   ├── models/
│   │   ├── staging/
│   │   └── marts/
│   │       └── fct_orders.sql (public)
│   └── dbt_project.yml
├── marketing_analytics/    # Domain-specific
│   ├── models/
│   │   └── marts/
│   │       └── fct_campaigns.sql
│   ├── dependencies.yml
│   └── dbt_project.yml
└── finance_analytics/      # Another domain
    └── ...
```

## dbt Explorer (Cross-Project Lineage)

dbt Explorer provides full cross-project lineage visualization for Mesh deployments.
Navigate upstream/downstream dependencies across project boundaries and track model
contract changes.

## Example Usage

```bash
# Install dependencies
dbt deps

# Build with cross-project refs
dbt build

# Check upstream contracts
dbt build --warn-error-options '{"include": ["PublicModelContractChange"]}'
```

## See Also

- [projects-environments](../concepts/projects-environments.md)
- [CI/CD Workflow](ci-cd-workflow.md)
