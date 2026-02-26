# Cortex Code Workflows

> **Purpose**: Using Cortex Code CLI and Snowsight for AI-assisted data development workflows
> **MCP Validated**: 2026-02-25

## When to Use

- Accelerating dbt model development and debugging
- Building Streamlit data applications from natural language
- Exploring and understanding unfamiliar Snowflake schemas
- Automating repetitive data engineering tasks
- Creating Cortex Agents for self-service analytics
- Data governance tasks (PII detection, tagging, RBAC setup)

## Implementation

```bash
# === Installation and Setup ===

# Install via pip
pip install snowflake-cortex-code

# Or via Homebrew (macOS)
brew install snowflake-cortex-code

# Authenticate with your Snowflake account
cortex-code auth login --account xy12345.us-east-1

# === Data Exploration ===

# Discover schema structure
cortex-code "list all tables in ANALYTICS_DB.GOLD with their row counts"

# Understand data lineage
cortex-code "trace the lineage of the F_SALES table back to sources"

# Profile data quality
cortex-code "check for null values and duplicates in D_CUSTOMER"

# === dbt Integration ===

# Generate dbt models from natural language
cortex-code "create a silver dbt model for the magento sales_order table
  with CDC filtering and snake_case column names"

# Debug failing models
cortex-code "why is the f_sales model failing? check the SQL and refs"

# Add tests to existing models
cortex-code "add not_null and unique tests to d_product.yml"

# === Streamlit App Development ===

# Generate complete Streamlit apps
cortex-code "build a Streamlit app showing daily revenue trends
  from GOLD.F_SALES with filters for region and product category"

# === Agent Building ===

# Create a Cortex Agent for business users
cortex-code "create a Cortex Agent that answers inventory questions
  using the GOLD.F_INVENTORYVIEW and GOLD.D_PRODUCT tables"

# === Data Governance ===

# Detect and tag PII
cortex-code "find all columns likely containing PII in ANALYTICS_DB
  and suggest appropriate masking policies"

# Set up RBAC
cortex-code "create a read-only role for the marketing team
  with access only to GOLD schema"
```

## Configuration

```markdown
# AGENTS.md (place in project root for custom behaviors)

## Project Context
This is a dbt project using Medallion Architecture on Redshift.
Bronze = source YAMLs, Silver = views, Gold = tables.

## Approved Operations
- Read any table in ANALYTICS_DB
- Create/modify models in models/ directory
- Run dbt commands via `uv run dbt`
- Execute SELECT queries

## Restricted Operations
- No DROP TABLE/DATABASE without explicit approval
- No modifications to production schemas
- No changes to RBAC without security review

## Custom Skills
- Use snake_case for silver models, UPPER_CASE for gold output
- Always include CDC filter: WHERE _ab_cdc_deleted_at IS NULL
- Follow CTE pattern: WITH source_data AS (...) SELECT ...
```

| CLI Flag | Purpose |
|----------|---------|
| `--model` | Select AI model (claude-opus-4-6, gpt-5.2) |
| `--profile` | Use named configuration profile |
| `--approve-all` | Auto-approve safe operations |
| `--dry-run` | Show plan without executing |
| `--output json` | Machine-readable output for CI/CD |

## Example Usage

```bash
# Interactive session with context persistence
cortex-code
> use database ANALYTICS_DB
> show me the most expensive queries from the last 24 hours
> optimize the top 3 by suggesting clustering keys
> create a monitoring dashboard in Streamlit

# CI/CD integration
cortex-code --output json \
  "validate all dbt models in models/gold/ for best practices" \
  > validation_report.json

# Batch operations
cortex-code "for each table in GOLD schema, generate YAML documentation
  with column descriptions based on the data and column names"
```

## See Also

- [cortex-code](../concepts/cortex-code.md)
- [roles-privileges](../concepts/roles-privileges.md)
