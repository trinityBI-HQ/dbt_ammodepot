# Roles and Privileges

> **Purpose**: Role-based access control (RBAC) for secure data governance, including Polaris catalog RBAC
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Snowflake uses RBAC combined with Discretionary Access Control (DAC). Roles are collections of privileges granted to users or other roles. Role hierarchies enable privilege inheritance. There is no super-user that bypasses authorization. System roles include ACCOUNTADMIN, SYSADMIN, SECURITYADMIN, and USERADMIN.

## The Pattern

```sql
-- Create custom roles following least privilege
CREATE ROLE data_analyst;
CREATE ROLE data_engineer;
CREATE ROLE data_admin;

-- Build role hierarchy
GRANT ROLE data_analyst TO ROLE data_engineer;
GRANT ROLE data_engineer TO ROLE data_admin;
GRANT ROLE data_admin TO ROLE sysadmin;

-- Grant database privileges
GRANT USAGE ON DATABASE analytics_db TO ROLE data_analyst;
GRANT USAGE ON SCHEMA analytics_db.reporting TO ROLE data_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics_db.reporting TO ROLE data_analyst;
GRANT SELECT ON FUTURE TABLES IN SCHEMA analytics_db.reporting TO ROLE data_analyst;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE analytics_wh TO ROLE data_analyst;

-- Grant write access to engineers
GRANT ALL ON SCHEMA analytics_db.staging TO ROLE data_engineer;
GRANT ALL ON ALL TABLES IN SCHEMA analytics_db.staging TO ROLE data_engineer;

-- Assign role to user
GRANT ROLE data_analyst TO USER jane_doe;
ALTER USER jane_doe SET DEFAULT_ROLE = data_analyst;
```

## Quick Reference

| System Role | Purpose |
|-------------|---------|
| ACCOUNTADMIN | Top-level, manages account settings |
| SYSADMIN | Creates warehouses, databases, roles |
| SECURITYADMIN | Manages grants, creates roles/users |
| USERADMIN | Creates/manages users and roles |
| PUBLIC | Default role for all users |

| Privilege | Applies To | Grants |
|-----------|------------|--------|
| USAGE | Database, Schema, Warehouse | Access to use object |
| SELECT | Table, View | Read data |
| INSERT/UPDATE/DELETE | Table | Modify data |
| CREATE | Schema | Create objects |
| OWNERSHIP | Any object | Full control |

| Open Catalog / Polaris RBAC | Description |
|-----------------------------|-------------|
| Catalog Admin | Full catalog management, SSO config |
| Namespace Admin | Create/drop namespaces and tables |
| Table Admin | Manage table properties and snapshots |
| Read-only | SELECT on Iceberg tables only |
| PrivateLink support | Secure cross-account access |

## Common Mistakes

### Wrong

```sql
-- Using ACCOUNTADMIN for daily work
USE ROLE accountadmin;
SELECT * FROM production.data;

-- Granting to PUBLIC
GRANT SELECT ON TABLE sensitive_data TO ROLE public;

-- Not using FUTURE grants
GRANT SELECT ON ALL TABLES IN SCHEMA reporting TO ROLE analyst;
-- New tables won't be accessible
```

### Correct

```sql
-- Use least-privilege role
USE ROLE data_analyst;
SELECT * FROM reporting.sales_summary;

-- Create specific roles for sensitive data
CREATE ROLE pii_reader;
GRANT SELECT ON TABLE customers_pii TO ROLE pii_reader;

-- Use FUTURE grants for new objects
GRANT SELECT ON FUTURE TABLES IN SCHEMA reporting TO ROLE analyst;

-- Horizon Catalog: unified governance with tagging and classification
-- Tag sensitive columns for compliance tracking
ALTER TABLE customers MODIFY COLUMN email SET TAG pii = 'email';
ALTER TABLE customers MODIFY COLUMN ssn SET TAG pii = 'ssn';
```

## Related

- [databases-schemas](../concepts/databases-schemas.md)
- [tables-views](../concepts/tables-views.md)
