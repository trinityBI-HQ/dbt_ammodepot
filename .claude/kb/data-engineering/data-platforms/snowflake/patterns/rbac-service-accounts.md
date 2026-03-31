# RBAC Service Account Patterns

> **Purpose**: Production patterns for Snowflake service accounts in a modern data stack
> **MCP Validated**: 2026-03-30

## When to Use

- Setting up dbt, Fivetran, Airbyte, or Dagster service accounts
- Configuring RSA key pair authentication for CI/CD
- Establishing least-privilege access for pipeline tools
- Onboarding a new ingestion or transformation service

## Standard Service Accounts

### dbt Transformer

```sql
-- SECURITYADMIN: Create role
CREATE ROLE IF NOT EXISTS DBT_TRANSFORMER_ROLE
    COMMENT = 'Role for dbt transformation service';
GRANT ROLE DBT_TRANSFORMER_ROLE TO ROLE SYSADMIN;

-- USERADMIN: Create user
CREATE USER IF NOT EXISTS DBT_TRANSFORMER_USER
    LOGIN_NAME = 'DBT_TRANSFORMER_USER'
    DISPLAY_NAME = 'dbt Transformer'
    DEFAULT_ROLE = DBT_TRANSFORMER_ROLE
    DEFAULT_WAREHOUSE = DBT_TRANSFORMING_WH
    DEFAULT_NAMESPACE = '<CLIENT>.DBT_DEV'
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Service account for dbt via Dagster/CI';

-- SECURITYADMIN: Assign role
GRANT ROLE DBT_TRANSFORMER_ROLE TO USER DBT_TRANSFORMER_USER;
```

**Permissions needed**:
- READ: All source databases/schemas (SELECT + USAGE)
- WRITE: All dbt output schemas (ALL on dev + prod layers)
- STREAM: SELECT on CDC streams (if using Dagster sensors)

### Ingestion Service (Fivetran/Airbyte)

```sql
-- SECURITYADMIN: Create role
CREATE ROLE IF NOT EXISTS INGESTION_ROLE
    COMMENT = 'Role for data ingestion services';
GRANT ROLE INGESTION_ROLE TO ROLE SYSADMIN;

-- USERADMIN: Create user (no password — key pair only)
CREATE USER IF NOT EXISTS SVC_FIVETRAN_USER
    LOGIN_NAME = 'SVC_FIVETRAN_USER'
    DISPLAY_NAME = 'Fivetran Ingestion'
    DEFAULT_ROLE = INGESTION_ROLE
    DEFAULT_WAREHOUSE = INGESTION_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Service account for Fivetran ingestion';

-- SECURITYADMIN: Assign role
GRANT ROLE INGESTION_ROLE TO USER SVC_FIVETRAN_USER;
```

**Permissions needed**:
- WRITE: Destination databases (ALL PRIVILEGES + CREATE SCHEMA)
- WAREHOUSE: USAGE + OPERATE (can suspend/resume)

## RSA Key Pair Authentication

### Generate Keys

```bash
# Generate 2048-bit RSA key pair (PKCS#8, unencrypted for CI/CD)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Extract public key body (base64, no headers)
grep -v "^-" rsa_key.pub | tr -d '\n'
```

### Register in Snowflake

```sql
-- SECURITYADMIN
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY = '<base64_body>';
ALTER USER SVC_FIVETRAN_USER SET RSA_PUBLIC_KEY = '<base64_body>';
```

### Zero-Downtime Key Rotation

```sql
-- 1. Set new key as secondary
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY_2 = '<new_key>';
-- 2. Update CI/CD to use new private key
-- 3. Promote new key to primary
ALTER USER DBT_TRANSFORMER_USER SET RSA_PUBLIC_KEY = '<new_key>';
ALTER USER DBT_TRANSFORMER_USER UNSET RSA_PUBLIC_KEY_2;
```

### CI/CD Integration

```bash
# GitHub Actions / Dagster Cloud: decode secret and write to temp file
echo "$SNOWFLAKE_PRIVATE_KEY" | base64 -d > /tmp/rsa_key.p8
export SNOWFLAKE_PRIVATE_KEY_PATH=/tmp/rsa_key.p8
```

```yaml
# dbt profiles.yml (never committed — use env vars)
my_project:
  target: prod
  outputs:
    prod:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: DBT_TRANSFORMER_USER
      private_key_path: "{{ env_var('SNOWFLAKE_PRIVATE_KEY_PATH') }}"
      private_key_passphrase: "{{ env_var('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE') }}"
      role: DBT_TRANSFORMER_ROLE
      warehouse: DBT_TRANSFORMING_WH
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
      schema: DBT_PROD_bronze
```

## Grant Templates

### Source Read Access (for dbt)

```sql
-- Full cascade for each source schema
GRANT USAGE ON DATABASE <source_db> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT USAGE ON SCHEMA <source_db>.<schema> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA <source_db>.<schema> TO ROLE DBT_TRANSFORMER_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA <source_db>.<schema> TO ROLE DBT_TRANSFORMER_ROLE;
```

### Destination Write Access (for ingestion)

```sql
-- Database-level: allow schema creation
GRANT USAGE ON DATABASE <dest_db> TO ROLE INGESTION_ROLE;
GRANT CREATE SCHEMA ON DATABASE <dest_db> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE <dest_db> TO ROLE INGESTION_ROLE;

-- Per-schema: full write access
GRANT ALL PRIVILEGES ON SCHEMA <dest_db>.<schema> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA <dest_db>.<schema> TO ROLE INGESTION_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA <dest_db>.<schema> TO ROLE INGESTION_ROLE;
```

## See Also

- [../concepts/roles-privileges.md](../concepts/roles-privileges.md)
- [rbac-multi-tenant.md](rbac-multi-tenant.md)
- `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md`
