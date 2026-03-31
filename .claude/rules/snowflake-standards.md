---
paths:
  - "**/*.sql"
  - "**/ROLES.md"
  - "**/USERS.md"
  - "**/WAREHOUSES.md"
  - "**/SCHEMAS.md"
  - "**/STREAMS.md"
  - "**/GRANTS.md"
---

# Snowflake RBAC Standards

> **Full reference**: `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md`

## Role Hierarchy (Enforced)

- All custom roles MUST be granted TO SYSADMIN
- No team member's default role should be a system role (ACCOUNTADMIN, SYSADMIN, etc.)
- Service accounts get dedicated roles: `{TOOL}_{PURPOSE}_ROLE`
- Team members get function roles: `{FUNCTION}_ROLE`

## Naming Conventions

- Service users: `SVC_{TOOL}_USER` or `{TOOL}_USER` (UPPERCASE)
- Team users: `{firstname}_snowflake` (lowercase)
- Roles: `{DESCRIPTOR}_ROLE` (UPPERCASE)
- Warehouses: `{PURPOSE}_WH` (UPPERCASE)
- Streams: `DAGSTER_STREAM__{TABLE_NAME}` (double underscore)

## Grant Rules

- Always include FUTURE grants alongside ALL grants (tables AND views)
- Grant cascade: DATABASE → SCHEMA → ALL TABLES → FUTURE TABLES
- Consumer roles: SELECT on Gold only. Never Bronze/Silver.
- dbt role: Read sources + write output schemas (ALL)
- Ingestion role: Write to destinations + CREATE SCHEMA

## Authentication

- Service accounts: RSA key pair (2048-bit, PKCS#8). No passwords.
- Team members: SSO (SAML2) when team >3 people
- Never store credentials in code, profiles.yml, or environment variables as plaintext

## Warehouse Rules

- Start X-Small for everything. 60s auto-suspend. Auto-resume enabled.
- Separate warehouses by workload type (ingestion, transformation, analytics)
- Ingestion role gets USAGE + OPERATE. All other roles get USAGE only.

## Tag Governance (Enforced)

- Every Snowflake account MUST have `GOVERNANCE.TAGS` schema with at minimum: `service`, `environment`, `client` tags
- Every warehouse MUST be tagged with `service` and `client`
- Every service account MUST be tagged with `service`
- Every database MUST be tagged with `client` and `environment`
- dbt projects MUST configure `query_tag` per layer: `dbt:bronze`, `dbt:silver`, `dbt:gold`
- Tags live in `GOVERNANCE.TAGS` — never in analytics schemas
- Use `ALLOWED_VALUES` on tags to prevent typos (except `client` which grows dynamically)
- Full taxonomy: `.claude/kb/data-engineering/data-platforms/snowflake/patterns/tag-governance.md`

## Provisioning

- All SQL: `CREATE IF NOT EXISTS` or `CREATE OR REPLACE` (idempotent)
- One object type per file
- Execution role documented at top of each file
- Execute in order: Roles → Users → Warehouses → Schemas → Streams → Tags → Grants → Key Auth
