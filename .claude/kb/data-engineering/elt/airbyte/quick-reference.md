# Airbyte Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Airbyte 2.0 Highlights (Oct 2025)

| Feature | Description |
|---------|-------------|
| **4-6x Faster Syncs** | New sync engine GA, rewritten for performance |
| **Data Activation** | Reverse ETL to CRMs, marketing, support tools (GA) |
| **Enterprise Flex** | Hybrid: managed control plane + self-hosted data planes |
| **AI-Configured Connections** | AI auto-configures connections from natural language (Dec 2025) |
| **Snowflake 10x Faster** | Snowflake destination 10x faster, 95% cheaper (Oct 2025) |
| **Files + Records** | Single connection syncs both files and records (v1.7, Jun 2025) |
| **Stream Templates** | Low-code CDK multi-stream generation (v1.7) |
| **Airbyte Plus** | New pricing tier between Cloud and Enterprise (Oct 2025) |

## Sync Modes

| Source Mode | Destination Mode | Behavior | Use Case |
|-------------|------------------|----------|----------|
| Full Refresh | Overwrite | Read all, replace destination | Schema changes, small datasets |
| Full Refresh | Append | Read all, append to destination | Audit logs, keep history |
| Incremental | Append | Read new/changed, append | Event streams, immutable data |
| Incremental | Append + Deduped | Read new/changed, append + dedupe view | Mutable records, CDC |

## Connector Types

| Type | Examples | Direction | Count |
|------|----------|-----------|-------|
| Source | Postgres, MongoDB, Salesforce, Stripe | Extract data FROM | 200+ |
| Destination | Snowflake, BigQuery, S3, Redshift | Load data TO | 50+ |
| Custom | REST API, GraphQL | Either | Build with CDK |

## Deployment Options

| Feature | OSS | Cloud | Plus | Enterprise | Enterprise Flex |
|---------|-----|-------|------|-----------|----------------|
| Cost | Free | Credits | Credits | License | License |
| Managed | No | Full | Full | Self | Hybrid |
| Data Plane | Self | Airbyte | Airbyte | Self | Self |
| Control Plane | Self | Airbyte | Airbyte | Self | Airbyte |
| RBAC/SSO | No | Basic | Yes | Yes | Yes |
| Support | Community | Standard | Priority | Premium | Premium |

## Python CDK Classes

| Class | Purpose | When to Use |
|-------|---------|-------------|
| `HttpStream` | REST API pagination | Most API connectors |
| `IncrementalMixin` | Incremental sync logic | Cursored endpoints |
| `Source` | Connector entry point | All connectors |
| `SourceDeclarativeManifest` | Low-code connector | 90% of use cases |

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/sources` | POST | Create source |
| `/v1/destinations` | POST | Create destination |
| `/v1/connections` | POST | Create connection |
| `/v1/jobs` | POST | Trigger manual sync |
| `/v1/connections/{id}/sync` | POST | Sync connection |

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `airbyte_source_<type>` | Define specific source connector |
| `airbyte_destination_<type>` | Define specific destination connector |
| `airbyte_source_custom` | Generic source with JSON config |
| `airbyte_destination_custom` | Generic destination with JSON config |
| `airbyte_connection` | Define sync between source/dest |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Pre-built connector exists | Use UI or Terraform |
| Custom API integration needed | Python CDK + HttpStream or Stream Templates |
| Orchestrate syncs in pipeline | Airbyte API + Dagster/Prefect |
| Multi-environment management | Terraform provider |
| High data volumes | Incremental Append + Deduped (4-6x faster in 2.0) |
| Schema frequently changes | Full Refresh Overwrite |
| Push data to CRMs/marketing | Data Activation (Reverse ETL) |
| Need complete control | OSS self-hosted |
| Prefer managed service | Airbyte Cloud or Plus |
| Hybrid: managed + self-hosted data | Enterprise Flex |
| Auto-configure connections | AI-Configured Connections |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Full Refresh for large tables | Incremental with cursor |
| Ignore normalization costs | Disable if using dbt downstream |
| Hardcode configs | Terraform for IaC |
| Deploy without CI/CD | Multi-environment strategy |
