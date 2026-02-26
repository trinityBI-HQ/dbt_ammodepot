# Databases and Schemas

> **Purpose**: Logical organization, namespacing, and governance of data objects in Snowflake
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Databases and schemas organize data in Snowflake. A database is a logical grouping of schemas, and each database belongs to a single Snowflake account. A schema is a logical grouping of database objects (tables, views, stages, etc.). Each schema belongs to a single database. Objects are referenced as `DATABASE.SCHEMA.OBJECT`.

## The Pattern

```sql
-- Create a database
CREATE DATABASE analytics_db
  DATA_RETENTION_TIME_IN_DAYS = 7  -- Time Travel retention
  COMMENT = 'Analytics data warehouse';

-- Create schemas for data layers
CREATE SCHEMA analytics_db.raw
  WITH MANAGED ACCESS;  -- Centralized privilege management

CREATE SCHEMA analytics_db.staging;
CREATE SCHEMA analytics_db.curated;
CREATE SCHEMA analytics_db.reporting;

-- Set default context
USE DATABASE analytics_db;
USE SCHEMA curated;

-- Clone database (zero-copy)
CREATE DATABASE analytics_db_dev CLONE analytics_db;
```

## Quick Reference

| Object | Scope | DDL Command |
|--------|-------|-------------|
| Database | Account | `CREATE DATABASE` |
| Schema | Database | `CREATE SCHEMA` |
| Table/View | Schema | `CREATE TABLE/VIEW` |

| Feature | Description |
|---------|-------------|
| Time Travel | Query/restore data up to 90 days (Enterprise) |
| Zero-copy Clone | Instant copy without storage duplication |
| Managed Access | Centralized grant control in schema |
| Horizon Catalog | Unified governance: data discovery, lineage, quality, compliance across clouds |
| Open Catalog / Polaris | Managed REST-based Iceberg catalog; engine-agnostic (Spark, Flink, Trino) |

## Common Mistakes

### Wrong

```sql
-- Everything in PUBLIC schema (no organization)
CREATE TABLE public.orders (...);
CREATE TABLE public.customers (...);
CREATE TABLE public.raw_orders (...);

-- Accessing objects without explicit schema
SELECT * FROM orders;  -- Relies on session context
```

### Correct

```sql
-- Organized by data layer
CREATE TABLE raw.orders_raw (...);
CREATE TABLE staging.orders_cleaned (...);
CREATE TABLE curated.dim_customers (...);
CREATE TABLE reporting.fact_orders (...);

-- Always use fully qualified names in production
SELECT * FROM analytics_db.curated.dim_customers;

-- Horizon Catalog: unified governance across clouds and open formats
-- Provides data discovery, lineage tracking, quality scores, and
-- compliance tagging across all Snowflake objects and external catalogs.
-- Open Catalog / Polaris: managed Iceberg REST catalog
-- Supports Delta Lake tables, SSO, PrivateLink, RBAC.
-- Engine-agnostic: Spark, Flink, Trino, Presto can read/write.
```

## Related

- [tables-views](../concepts/tables-views.md)
- [roles-privileges](../concepts/roles-privileges.md)
