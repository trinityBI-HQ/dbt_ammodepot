# dbt Project Audit Backlog

**Audit date:** 2026-02-26
**Audited by:** 3 specialist agents (dbt-expert, medallion-architect, web researcher)
**Benchmarked against:** 160+ industry criteria (dbt Labs, dbt-project-evaluator, Datafold, community)
**Overall score:** 8.0 / 10

---

## Scorecard

| # | Category | Score | Rating |
|---|----------|:-----:|--------|
| 1 | Project Structure & Organization | 8.5 | Excellent |
| 2 | Model Design & SQL Quality | 7 | Good |
| 3 | Testing Coverage | 8 | Very Good |
| 4 | Documentation | 8 | Very Good |
| 5 | Materializations & Performance | 8 | Very Good |
| 6 | Source Definitions & Freshness | 9 | Excellent |
| 7 | DRY Principles & Reusability | 8 | Very Good |
| 8 | Configuration Management | 9 | Excellent |
| 9 | Data Quality & Defensive Coding | 8 | Very Good |
| 10 | dbt Best Practices Compliance | 9 | Excellent |
| 11 | Layer Separation (Medallion) | 7 | Good |
| 12 | Silver Layer Quality | 6 | Needs Work |
| 13 | Data Lineage | 8 | Very Good |

---

## CRITICAL — Fixed in PR #13

- [x] **C1** Remove `password_hash` PII from `d_customer.sql` Gold output _(security)_
- [x] **C2** Remove `_ab_cdc_cursor` and `_ab_cdc_log_pos` CDC metadata from `d_customer.sql` Gold output _(data governance)_
- [x] **C3** Replace `SELECT *` with explicit column lists in 12 Silver models + 1 intermediate _(schema drift risk)_

## HIGH — Fixed in PR #13

- [x] **H3** Replace `cf.*` wildcard in `d_product.sql` with 38 explicit columns
- [x] **H3** Replace `dv.*` wildcard in `d_customer_segmentation.sql` with 15 explicit columns
- [x] **H5** Fix `SELECT *` in `int_magento_product_eav_lookups.sql` line 2

## LOW — Fixed in PR #13

- [x] **L1** Remove deprecated `version: 2` header from 41 YAML files

---

## HIGH — Backlog

- [ ] **H1** Fix `magento_d_customerupdated.sql`: add CDC filter (`WHERE _ab_cdc_deleted_at IS NULL`), rename file to remove `d_` prefix, fix UPPER_CASE usage in Silver layer
  - File: `models/silver/magento/magento_d_customerupdated.sql`
  - Rename to: `magento_customer_email_rank.sql` (or similar)
  - Impact: `d_customer_segmentation.sql` references this model

- [ ] **H2** Strip CDC metadata columns from Silver model outputs (23 models pass through `_ab_cdc_cursor`, `_ab_cdc_log_pos`, `_ab_cdc_log_file`, `_ab_cdc_updated_at`)
  - Key files: `magento_sales_order.sql`, `magento_customer_entity.sql`
  - Action: Remove CDC columns from the final SELECT in each Silver model

- [ ] **H4** Parameterize hardcoded status/type IDs in 15+ inventory models as `var()` definitions
  - `tag_type_id in (30, 40)` — `inventory_qtyonhand.sql`, `inventory_qtynotavailable.sql`, etc.
  - `status_id in (20, 25)` — `inventory_qtyallocatedso.sql`, `inventory_qtydropship.sql`, etc.
  - `order_type_id = 10` — `inventory_qtyonorderpo.sql`
  - `item_type_id = 12` — `inventory_qtydropship.sql`
  - `status_id < 40` — `inventory_qtyallocatedmo.sql`, `inventory_qtyonordermo.sql`
  - Action: Add ~15 new `ammodepot_*` vars to `dbt_project.yml`

---

## MEDIUM — Backlog

- [ ] **M2** Add UPPER_CASE aliases to `d_vendor.sql` for Gold layer consistency + rename `fishbowl_vendor_parts.sql` columns to snake_case
  - Reverted from PR #13 to avoid breaking Power BI dashboards
  - Requires coordinated Power BI update before implementing
  - Also update: `d_vendor.yml`, `f_pos.yml` FK ref, `int_fishbowl_product_enrichment.sql`

- [ ] **M1** Evaluate thin Gold pass-through models (`d_customer.sql`, `d_store.sql`, `d_vendor.sql`) — add business logic or document justification as BI interface layer
  - These are 1:1 mappings from Silver with only UPPER_CASE aliasing
  - Acceptable if explicitly documented as "BI interface" models

- [ ] **M3** Replace Portuguese column aliases in `f_sales.sql` with English equivalents
  - Line 301: `"Inicio da Hora - Copiar"` → English name
  - Line 310: `"Inicio da Hora"` → English name
  - Line 40: `chave` → `key` or descriptive English name
  - Impact: Requires coordinated Power BI update

- [ ] **M4** Fix VARCHAR casting for joins in `f_shippment.sql` (lines 85-88, 147-155, 202)
  - `CAST(x as VARCHAR) = CAST(y as VARCHAR)` prevents index usage
  - Action: Align types in Silver layer so joins use native types

- [ ] **M5** Convert hardcoded customer groups to a seed CSV
  - File: `d_customer_segmentation.sql` lines 180-190
  - Replace UNION ALL with `{{ ref('seed_customer_groups') }}`
  - Create `seeds/customer_groups.csv`

- [ ] **M6** Parameterize RFM thresholds in `d_customer_segmentation.sql` as `var()`
  - Revenue buckets: 149/225/300/500
  - Recency thresholds: 30/60/180/240/365 days
  - Frequency thresholds: 1/2/3/5
  - Margin thresholds: 0.20/0.24/0.26/0.30

- [ ] **M8** Create `convert_uom()` macro for UOM conversion logic duplicated in 9 inventory models
  - Pattern: `WHEN uom_id <> default_uom_id THEN qty * multiply_factor / factor`
  - Files: `inventory_qtyonorderpo`, `inventory_qtyallocatedso`, `inventory_qtyallocatedmo`, `inventory_qtyallocatedtosend`, `inventory_qtyallocatedtoreceive`, `inventory_qtyonorderso`, `inventory_qtyonordermo`, `inventory_qtyonordertoreceive`, `inventory_qtyonordertosend`

- [ ] **M9** Create `resolve_eav_attribute()` macro for repeated EAV lookup pattern in `int_magento_product_eav_lookups.sql`
  - 10 nearly identical CTEs (lines 22-140), each doing JOIN + WHERE attribute_id = var()
  - Saves ~100 lines

- [ ] **M10** Fix naming inconsistency: `fishbowl_customers.sql` and `fishbowl_vendors.sql` use plural, all others singular
  - Rename to `fishbowl_customer.sql` and `fishbowl_vendor.sql`
  - Impact: Update all `ref()` calls downstream

- [ ] **M11** Evaluate incremental materialization for Gold fact tables
  - `f_sales` is the strongest candidate (use `item_created_at` as watermark)
  - Also evaluate `f_pos`, `f_shippment`, `f_inventoryview`
  - Current: full table rebuild on every `dbt build`

---

## LOW — Backlog

- [ ] **L2** Consolidate custom generic tests that overlap with `dbt_expectations`
  - `assert_non_negative_values` → `expect_column_values_to_be_between`
  - `assert_date_range` → `expect_column_values_to_be_between`
  - `assert_valid_email_format` → `expect_column_values_to_match_regex`
  - `assert_numeric_range` → `expect_column_values_to_be_between`

- [ ] **L3** Document that inventory models (`silver/inventory/`) intentionally blur Silver/Intermediate boundary
  - They perform multi-table joins and aggregations at the Silver layer
  - Acceptable design choice if documented

- [ ] **L4** Rename `f_shippment.sql` to `f_shipment.sql` (typo)
  - Deferred: requires coordinated Power BI update
  - Track as future cleanup when BI migration window opens

- [ ] **L5** Add source-level tags for selective freshness checks
  - Add `tags: ['fishbowl']` and `tags: ['magento']` to source definitions
  - Enables: `dbt source freshness --select tag:fishbowl`

- [ ] **L6** Clarify `dbt_date` package status
  - Present in `package-lock.yml` but not in `packages.yml`
  - Either add to `packages.yml` or remove from lock file

- [ ] **L7** Add singular tests for complex business logic
  - Cost waterfall in `f_sales` (unique Magento ID → duplicate → average → weighted average)
  - RFM segmentation boundaries in `d_customer_segmentation`
  - EAV attribute resolution correctness

- [ ] **L8** Define exposures for Power BI dashboards
  - Map Gold models to their BI consumers
  - Enables lineage visibility: `dbt docs generate` shows end-to-end flow
  - Example: `exposure: dashboard_sales_overview` → depends on `f_sales`, `d_product`, `d_customer_segmentation`

---

## Tooling — Backlog

- [ ] **T1** Install `dbt-project-evaluator` package (v1.2.2) for automated auditing
  ```yaml
  # packages.yml
  packages:
    - package: dbt-labs/dbt_project_evaluator
      version: [">=1.2.0", "<2.0.0"]
  ```
  ```yaml
  # dbt_project.yml (required for Redshift)
  dispatch:
    - macro_namespace: dbt
      search_order: ['dbt_project_evaluator', 'dbt']
  ```
  Run: `dbt build --select package:dbt_project_evaluator`

- [ ] **T2** Add `dbt-checkpoint` pre-commit hooks for automated linting
  ```yaml
  # .pre-commit-config.yaml
  repos:
    - repo: https://github.com/dbt-checkpoint/dbt-checkpoint
      rev: v2.0.3
      hooks:
        - id: check-model-has-tests
          args: ['--test-cnt', '1']
        - id: check-model-has-description
        - id: check-source-has-freshness
        - id: check-script-has-no-table-name
        - id: check-script-semicolon
  ```

- [ ] **T3** Set up CI pipeline to run `dbt build` on PRs (slim CI with modified models only)

- [ ] **T4** Add data observability (Elementary or dbt_expectations anomaly detection) for critical Gold models

---

## Industry Benchmark Summary

| Category | Met | Total | % |
|---|:---:|:---:|:---:|
| Project Config & Setup | 10 | 14 | 71% |
| Structure & Organization | 12 | 13 | 92% |
| Naming Conventions | 7 | 10 | 70% |
| SQL Style & Code Quality | 19 | 24 | 79% |
| DAG / Modeling | 13 | 16 | 81% |
| Testing | 12 | 18 | 67% |
| Documentation | 9 | 12 | 75% |
| Materialization & Performance | 6 | 12 | 50% |
| Source Management | 8 | 9 | 89% |
| Governance & Access Control | 1 | 10 | 10% |
| CI/CD | 4 | 11 | 36% |
| Security | 5 | 8 | 63% |
| Observability & Monitoring | 1 | 7 | 14% |
| **Overall** | **107** | **164** | **65%** |

**Maturity Level: 4 — Measured** (standards enforced, some automation, metrics tracked)

**Biggest gaps:** Governance (10%), Observability (14%), CI/CD (36%), Performance/Materialization (50%)

---

## Prioritized Roadmap

### Phase 1 — Security & Quality (PR #13 - DONE)
- [x] PII removal, SELECT * elimination, wildcard fixes, version headers

### Phase 2 — Configuration Consistency
- [ ] H4: Parameterize inventory IDs
- [ ] M5: Customer groups seed
- [ ] M6: RFM thresholds as vars

### Phase 3 — DRY & Macros
- [ ] M8: `convert_uom()` macro
- [ ] M9: `resolve_eav_attribute()` macro
- [ ] H2: Strip CDC metadata from Silver outputs

### Phase 4 — Naming & Cleanup
- [ ] H1: Fix `magento_d_customerupdated` naming/CDC
- [ ] M10: Singular/plural naming
- [ ] M3: Portuguese aliases

### Phase 5 — Performance
- [ ] M11: Incremental materialization evaluation
- [ ] M4: VARCHAR casting fixes

### Phase 6 — Governance & Observability
- [ ] L8: Power BI exposures
- [ ] T1: dbt-project-evaluator
- [ ] T3: CI pipeline
- [ ] T4: Data observability
