# Section 1: New Project Checklist

> **Delivery Standards** — trinityBI Engineering
>
> Last updated: 2026-03-30

---

**Purpose**: Single entry point for setting up a new client dbt project from scratch. References all other standards — follow the links, don't duplicate.

---

## Phase 1: Snowflake Account Setup

> **Full reference**: `.claude/docs/06_SNOWFLAKE_RBAC_STANDARDS.md`

Execute in this order (one file per step):

- [ ] **1.1 Roles** — Create custom roles (SECURITYADMIN). Grant all to SYSADMIN.
- [ ] **1.2 Users** — Create service accounts: `DBT_TRANSFORMER_USER`, `SVC_FIVETRAN_USER` (USERADMIN).
- [ ] **1.3 Warehouses** — Create `DBT_TRANSFORMING_WH`, `INGESTION_WH` — X-Small, 60s auto-suspend (SYSADMIN).
- [ ] **1.4 Database & Schemas** — Create client database + `DBT_DEV`, `DBT_PROD_bronze`, `DBT_PROD_silver`, `DBT_PROD_gold` (SYSADMIN).
- [ ] **1.5 Tags** — Create `GOVERNANCE.TAGS` if first client. Apply `service`, `client`, `environment` tags to all objects.
  > Tag taxonomy: `.claude/kb/data-engineering/data-platforms/snowflake/patterns/tag-governance.md`
- [ ] **1.6 Streams** — Create CDC streams if using event-driven orchestration (SYSADMIN).
- [ ] **1.7 Grants** — Full grant cascade: dbt read sources + write outputs, ingestion write destinations, consumers read Gold only.
- [ ] **1.8 Key Auth** — Register RSA public keys for service accounts (SECURITYADMIN).
- [ ] **1.9 Verify** — Run `SHOW GRANTS TO ROLE <role>` for all roles. Test SELECT from each source.

---

## Phase 2: dbt Project Setup

> **Full reference**: `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md`

- [ ] **2.1 Scaffold** — Create project folder structure:
  ```text
  models/
  ├── bronze/{source}/       # 1:1 with source, views, source() only here
  ├── silver/{domain}/       # Business logic, joins, dedup
  ├── gold/{domain}/         # Consumption-ready, plain names
  └── intermediate/{domain}/ # Ephemeral/views, never exposed
  macros/
  ├── generate_schema_name.sql
  └── {domain}/
  ```
- [ ] **2.2 dbt_project.yml** — Configure:
  - Materializations per layer (Section 5.1)
  - Schema routing per layer (Bronze/Silver/Gold/Intermediate)
  - `query_tag` per layer: `dbt:bronze`, `dbt:silver`, `dbt:gold`
  - Variables for business logic (no hardcoded values)
- [ ] **2.3 profiles.yml** — Configure Snowflake connection (never committed):
  - RSA key pair auth
  - Dev: single `DBT_DEV` schema
  - Prod: layer-separated schemas
- [ ] **2.4 packages.yml** — Add `dbt_utils`, `dbt_expectations`. Pin versions.
- [ ] **2.5 generate_schema_name macro** — Copy from standards (Section 5.1).
- [ ] **2.6 Sources** — Create `_{source}__sources.yml` with freshness config (24h warn, 48h error).
- [ ] **2.7 Bronze models** — 1:1 with source. Explicit column lists, CDC filtering if applicable.
- [ ] **2.8 .sqlfluff** — Configure linter with jinja templater for CI, dbt templater for local.

---

## Phase 3: Testing & Documentation

> **Full reference**: `.claude/docs/05_DBT_DATA_PRACTICE_STANDARDS.md` Section 5.3

- [ ] **3.1 Schema YAML** — Every model has `description` + column-level tests.
- [ ] **3.2 PK tests** — `unique` + `not_null` on every model's primary key.
- [ ] **3.3 FK tests** — `relationships` on every foreign key (severity: warn).
- [ ] **3.4 Gold assertions** — At least 1 business logic test per Gold model.
- [ ] **3.5 Severity pyramid** — Gold: error, Silver PKs: error, Bronze: warn.
- [ ] **3.6 Exposures** — YAML entry for every Gold model consumed by BI/API.

---

## Phase 4: CI/CD

> **Full reference**: `.claude/docs/04_GIT_AND_WORKFLOW.md`

- [ ] **4.1 GitHub repo** — Initialize with `.gitignore` (profiles.yml, target/, dbt_packages/).
- [ ] **4.2 Branch protection** — Require PR, no direct push to main.
- [ ] **4.3 CI workflow** — GitHub Actions: flake8 + sqlfluff + `dbt parse` on every PR.
- [ ] **4.4 dbt build workflow** — Conditional `dbt build` against Snowflake when models/macros change.
- [ ] **4.5 Production deploy** — Auto-deploy on merge to main (Dagster Cloud PEX, ECS, or equivalent).
- [ ] **4.6 Secrets** — Store Snowflake private key + passphrase in GitHub Secrets (or AWS Secrets Manager).

---

## Phase 5: Orchestration

- [ ] **5.1 Choose orchestrator** — See cost comparison in Section 5.7 of dbt standards.
- [ ] **5.2 Schedule** — Daily cron at minimum. Configure CDC sensors if using Snowflake Streams.
- [ ] **5.3 Alerting** — Failure notifications (Slack, email, or Google Chat webhook).
- [ ] **5.4 Service account** — Orchestrator uses `DBT_TRANSFORMER_USER` with RSA key pair.

---

## Phase 6: Sync & Document

- [ ] **6.1 Sync .claude/** — Run `/sync-repos --target <new_project>` from claude-code-lab.
- [ ] **6.2 CLAUDE.md** — Create project-specific CLAUDE.md documenting:
  - Architecture overview
  - Source systems and ingestion
  - Key design decisions
  - Snowflake objects (databases, schemas, warehouses, roles)
  - Deployment workflow
- [ ] **6.3 README.md** — Architecture diagram (Mermaid), tech stack, project structure.
- [ ] **6.4 Update RBAC manager** — Add new client's schemas, grants, and streams to snowflake-rbac-manager.

---

## Post-Setup Verification

Run these after completing all phases:

```bash
# dbt compiles and all tests pass
dbt build --target dev

# Source freshness check passes
dbt source freshness

# CI pipeline is green
git push origin feat/initial-setup && gh pr create
```

---

*Each checkbox is a gate — don't move to the next phase until the current one is verified.*
