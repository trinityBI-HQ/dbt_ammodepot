# Data Contracts Pattern

> **Purpose**: Enforce schema stability on Gold models consumed by external systems
> **Requires**: dbt-core 1.9+ (contracts GA)
> **MCP Validated**: 2026-03-30

## When to Use

- Gold models consumed by BI tools (Power BI, Looker, Tableau)
- Gold models consumed by reverse ETL or APIs
- Any model where a column rename/removal would break a downstream system
- When onboarding new consumers who need schema guarantees

## Implementation

### Basic Contract

```yaml
# models/gold/_sales__models.yml
models:
  - name: orders
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: varchar(36)
        constraints:
          - type: not_null
          - type: primary_key
      - name: customer_id
        data_type: varchar(36)
        constraints:
          - type: not_null
      - name: order_date
        data_type: date
        constraints:
          - type: not_null
      - name: total_amount
        data_type: number(18,2)
      - name: status
        data_type: varchar(50)
```

### What Contracts Enforce

| Constraint | Behavior |
|-----------|----------|
| Column names | Build fails if model SQL outputs a column not in the contract |
| Column order | Must match YAML definition order |
| Data types | Must match declared `data_type` |
| `not_null` | Adds warehouse-level NOT NULL constraint |
| `primary_key` | Declares PK (enforcement depends on warehouse) |
| `foreign_key` | Declares FK relationship |
| `unique` | Adds uniqueness constraint |

### Contract with Access Groups

```yaml
# models/gold/_sales__models.yml
models:
  - name: orders
    access: public          # Visible to other dbt projects
    group: sales            # Belongs to the sales group
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: varchar(36)
```

```yaml
# models/_groups.yml
groups:
  - name: sales
    owner:
      name: Analytics Team
      email: analytics@company.com
```

### Access Levels

| Level | Who Can `ref()` It | Use For |
|-------|-------------------|---------|
| `private` | Same group only | Internal intermediate models |
| `protected` | Same project (default) | Most models |
| `public` | Any project (cross-project refs) | Stable Gold models with contracts |

## Migration Path

### Adding Contracts to Existing Models

1. Run `dbt show --select model_name` to capture current column output
2. Add `contract: {enforced: true}` to schema YAML
3. Declare all columns with `data_type` matching current output
4. Run `dbt build --select model_name` to validate
5. Fix any column order or type mismatches

### Common Gotchas

- **Column order matters**: YAML column order must match SELECT order in SQL
- **Implicit types**: Snowflake `NUMBER` defaults to `NUMBER(38,0)` — be explicit
- **Aliases**: Contract validates the output alias, not the source column name
- **Ephemeral models**: Cannot have contracts (no physical table to constrain)

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `contract.enforced` | `false` | Enable schema enforcement |
| `access` | `protected` | Visibility level for cross-project refs |
| `group` | None | Ownership group for the model |

## Testing with Contracts

Contracts complement but don't replace dbt tests:

| Check | Contract | dbt Test |
|-------|----------|----------|
| Column exists | Yes | No |
| Column type correct | Yes | No |
| Column not null | Yes (constraint) | Yes (data test) |
| Column unique | Yes (constraint) | Yes (data test) |
| Value ranges | No | Yes |
| Business logic | No | Yes |
| Referential integrity | Declared, not enforced | Yes |

**Recommendation**: Use contracts for schema stability + dbt tests for data quality.

## See Also

- [testing-strategy.md](testing-strategy.md)
- [best-practices.md](best-practices.md)
- [../concepts/models.md](../concepts/models.md)
