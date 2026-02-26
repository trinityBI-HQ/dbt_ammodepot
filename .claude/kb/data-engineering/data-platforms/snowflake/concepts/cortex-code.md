# Cortex Code

> **Purpose**: AI-native coding agent for data engineering, analytics, and ML within Snowflake
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-25

## Overview

Cortex Code is Snowflake's AI-driven intelligent agent for automating data engineering, analytics, machine learning, and agent-building tasks. It uses an autonomous agent framework with deep understanding of Snowflake RBAC, schemas, and best practices. Available as both a CLI tool (GA Feb 2026) and Snowsight integration (Preview Feb 2026). Since its November 2025 launch, it has added over 4,400 users with reported 5-10x productivity gains.

## The Pattern

```bash
# Install Cortex Code CLI
pip install snowflake-cortex-code

# Authenticate (uses existing Snowflake connection config)
cortex-code auth login --account xy12345.us-east-1

# Natural language queries
cortex-code "find all tables with PII tags in the ANALYTICS database"

cortex-code "generate a Streamlit app for SALES_MART.REVENUE"

cortex-code "create a dbt model that joins orders with customers"

# Execute SQL through natural language
cortex-code "show me the top 10 customers by revenue this month"

# Build data pipelines
cortex-code "create a dynamic table that aggregates daily sales"

# Agent creation
cortex-code "build a Cortex Agent that answers questions about inventory"
```

## Quick Reference

| Interface | Status | Cost | Use Case |
|-----------|--------|------|----------|
| CLI | GA (Feb 2026) | Token-based billing | Power users, developers, CI/CD |
| Snowsight | Preview (Feb 2026) | Free during preview | Interactive exploration, notebooks |

| Skill | Description |
|-------|-------------|
| Data Engineering | Build pipelines, dynamic tables, transformations |
| Analytics | SQL queries, dashboards, Streamlit apps |
| Machine Learning | Model training, Snowflake ML integration |
| Agent Creation | Build Cortex Agents with tools and skills |
| Data Governance | Tag management, PII detection, RBAC setup |

| Feature | Details |
|---------|---------|
| Model support | Claude Opus 4.6, OpenAI GPT-5.2 (configurable) |
| Extensibility | Custom tools, skills, subagents, hooks, profiles |
| External support | dbt, Apache Airflow (Feb 2026 expansion) |
| Security | Full RBAC, OS-level sandboxing, 3-tier approval |
| Standalone plan | Available without Snowflake compute (Feb 2026) |

## Common Mistakes

### Wrong

```bash
# Running without proper RBAC context
cortex-code "drop all staging tables"
# Risk: Agent will execute with your current role's permissions

# Ignoring the approval system for destructive operations
# Cortex Code uses a 3-tier approval: auto/confirm/deny
```

### Correct

```bash
# Use specific, scoped requests
cortex-code "list all staging tables in ANALYTICS_DB.STAGING"

# Review changes before applying (CLI shows visual diffs)
cortex-code "optimize the slow query in REPORTS.DAILY_REVENUE"
# Agent proposes changes -> you review diff -> approve/reject

# Configure AGENTS.md for custom workflows
# Place AGENTS.md in your project root to define:
# - Custom skills and behaviors
# - Approved operations
# - Project-specific context
```

## Related

- [virtual-warehouses](../concepts/virtual-warehouses.md)
- [roles-privileges](../concepts/roles-privileges.md)
