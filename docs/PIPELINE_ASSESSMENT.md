# AmmoDepot Pipeline Assessment & Improvement Plan

**Date:** 2026-02-26
**Scope:** End-to-end data pipeline — from source systems through Power BI dashboards
**Based on:** Airbyte connections audit, Power BI data source mapping, Snowflake view discovery, data lineage screenshots, dbt project audit

---

## 1. Current State — The Full Picture

### 1.1 Source Systems

| System | Purpose | Data |
|--------|---------|------|
| **Fishbowl** | ERP / Inventory management | Sales orders, products, parts, vendors, shipping, POs, kits, UOM |
| **Magento** | E-commerce platform | Orders, customers, products (EAV), catalog, addresses |
| **UPS Invoice History** | Freight billing | Actual shipping costs by tracking number |
| **Base-Subjects.xlsx** | Excel file (via gateway) | Unknown scope — feeds Listrak Overview report |

### 1.2 Ingestion Layer (Airbyte)

**7 active connections** ingesting into 2 warehouses in parallel:

| Connection | Source | Destination | Streams | Frequency | Status |
|------------|--------|-------------|---------|-----------|--------|
| FB→RS: Incremental Critical | Fishbowl | Redshift | 18 | 1 hour | ACTIVE — `so`, `soitem`, `part`, `product` migrated to Incremental+Dedup |
| FB→RS: Full Refresh Light | Fishbowl | Redshift | 16 | 6 hours | ACTIVE — slow-changing tables split from main connection |
| MGT→RS (SALES) | Magento | Redshift | 1 | 1 hour | ACTIVE — `sales_order` only (migrated to Incremental+Dedup), 5 duplicates removed |
| MGT→RS (CATALOG) | Magento | Redshift | 1 | 1 hour | ACTIVE |
| MGT→RS (main) | Magento | Redshift | ~20 | 1 hour | ACTIVE (production) |
| FB→SF | Fishbowl | Snowflake | 13 | Cron | ACTIVE (well configured) |
| MGT→SF (SO e SOI) | Magento | Snowflake | 18 | Cron | ACTIVE (well configured) |
| ~~FB→RS (so+soitem)~~ | ~~Fishbowl~~ | ~~Redshift~~ | ~~3~~ | ~~1 hour~~ | DELETED (Phase 0) |
| (Fivetran legacy) | Magento | PC_FIVETRAN_DB | Unknown | Unknown | LEGACY — still in use |

### 1.3 Processing Layer — Two Parallel Worlds

Here is the key insight: **there are TWO completely independent processing paths running simultaneously**, serving different parts of the same Power BI reports.

#### Path A: dbt on Redshift (governed, tested)
```
Fishbowl/Magento → Airbyte → Redshift Bronze → dbt Silver (views) → dbt Gold (tables) → Power BI
```
- 95 dbt models, 339 tests, automated dbt Cloud runs
- Medallion architecture (Bronze/Silver/Gold)
- Version controlled, CI-tested, audited (8.0/10)
- Gold schema: `gold.f_sales`, `gold.d_product`, `gold.d_customer_segmentation`, etc.

#### Path B: Hand-crafted Snowflake views (ungoverned, untested)
```
Fishbowl/Magento → Airbyte → Snowflake raw → Manual SQL views → Power BI
```
- 17 hand-written Snowflake views across 3 schemas (`AD_REALTIME`, `TEST_DTO`, `AIRBYTE_SCHEMA`)
- No version control, no tests, no documentation
- Contains complex business logic (cost waterfalls, freight allocation, cohorts)
- Hardcoded attribute IDs, `SELECT *`, Portuguese comments
- One view reads from `PC_FIVETRAN_DB` (legacy Fivetran connection)

### 1.4 Serving Layer — Power BI Dataflows

**6 Power BI Dataflows (Gen1)** pull data from both paths:

| Dataflow | Source | Tables Pulled | Refresh Status |
|----------|--------|---------------|----------------|
| **Data Warehouse Redshift** | Redshift (dbt Gold) + Snowflake (AD_REALTIME) | f_sales, d_product, d_store, f_inventoryview, f_pos, d_vendor, d_product_bundle, f_shippment, d_customer_segmentation + f_sales_realtime, d_product_realtime | Refreshed 2/25/26 |
| **Data Warehouse** (old Snowflake) | Snowflake (TEST_DTO) | f_cohort, d_store, d_product, f_shippment, d_customersegmentation, d_customerupdated, inventoryconversion | **Last refresh: 12/31/25** |
| **Once Per Day Updates** | Snowflake (TEST_DTO) | f_cohort, f_cohortdetailed | Refreshed 2/25/26 |
| **SALES OVERVIEW REALTIME** | Snowflake (AD_REALTIME) | F_SALES_REALTIME | Active |
| **Product List** | Snowflake (TEST_DTO + AIRBYTE_SCHEMA) | d_product, d_vendor, inventoryconversion | Refreshed 2/25/26 |
| (Unnamed - Fivetran) | PC_FIVETRAN_DB | d_user | Legacy |

### 1.5 Power BI Reports

**Actively refreshing (2025-2026):**
| Report | Primary Dataflow |
|--------|-----------------|
| SALES OVERVIEW REDSHIFT | Data Warehouse Redshift |
| INVENTORY REDSHIFT | Data Warehouse Redshift |
| CROSSELING REDSHIFT | Data Warehouse Redshift |
| CLIENT ANALYSIS REDSHIFT | Data Warehouse Redshift |
| SHIPPING ANALYSIS REDSHIFT | Data Warehouse Redshift |
| SALES OVERVIEW FASTER | Data Warehouse Redshift |

**Stale / broken (last refresh 2025 or earlier):**
| Report | Last Refresh | Issue |
|--------|-------------|-------|
| CLIENT ANALYSIS | 5/27/25 | Uses old "Data Warehouse" Snowflake dataflow (last refresh 12/31/25) |
| SALES OVERVIEW | 5/27/25 | Same — stale dataflow |
| SHIPPING ANALYSIS | 7/3/25 | Warning icon — likely broken |
| INVENTORY | 6/23/25 | Stale — 8 months old |
| AFFILIATEUPDATE | 7/29/25 | Warning icon — likely broken |
| CROSSELING | 5/27/25 | Stale |
| LISTRAK OVERVIEW | 7/22/25 | Warning icon — uses Excel file + Fivetran Snowflake |

---

## 2. Critical Findings

### 2.1 Duplicate/Conflicting Data Paths

This is the root cause of the chaos. The same business entity is being served to Power BI through different paths, with different logic:

| Entity | Path A (dbt/Redshift) | Path B (Snowflake views) | Conflict? |
|--------|----------------------|--------------------------|-----------|
| **f_sales** | `gold.f_sales` — full history, dbt-tested, Redshift cost waterfall | `AD_REALTIME.F_SALES_REALTIME_LASTDAYS` — last 4 days, Snowflake-native cost waterfall | **YES** — different cost calculation logic |
| **d_product** | `gold.d_product` — EAV via dbt vars, tested | `TEST_DTO.D_PRODUCT` / `AD_REALTIME.D_PRODUCT_REALTIME` — hardcoded attribute IDs | **YES** — different attribute resolution |
| **d_customer** | `gold.d_customer_segmentation` — RFM scoring | `TEST_DTO.D_CUSTOMERSEGMENTATION` — different RFM logic? | **LIKELY** |
| **f_shippment** | `gold.f_shippment` — Fishbowl ship data | `TEST_DTO.F_SHIPPMENT` — unknown differences | **UNKNOWN** |
| **d_store** | `gold.d_store` | `TEST_DTO.D_STORE` | **UNKNOWN** |
| **d_vendor** | `gold.d_vendor` | `AIRBYTE_SCHEMA.D_VENDOR` | **UNKNOWN** |
| **f_inventoryview** | `gold.f_inventoryview` | `AIRBYTE_SCHEMA.F_INVENTORYVIEW` | **UNKNOWN** |
| **f_pos** | `gold.f_pos` | `AIRBYTE_SCHEMA.F_POS` | **UNKNOWN** |
| **f_cohort** | Does not exist in dbt | `TEST_DTO.F_COHORT` / `F_COHORTDETAILED` | **GAP** — only in Snowflake |
| **d_user** | Does not exist in dbt | `PC_FIVETRAN_DB...D_USER` | **GAP** — legacy Fivetran only |
| **f_sales_realtime** | Does not exist in dbt | `AD_REALTIME.F_SALES_REALTIME` | **GAP** — only in Snowflake |

### 2.2 Airbyte Connection Redundancies (from your audit)

| Issue | Streams | Risk | Priority |
|-------|---------|------|----------|
| **FB→RS (so+soitem) is entirely duplicate** | `so`, `soitem`, `upsview_ad_a` | Double-writing same data, Full Refresh hourly | CRITICAL |
| **MGT→RS (SALES) duplicates 5 streams** from main Magento connection | `amasty_*` (4), `magento_image_optimizer` | Wasted compute, potential inconsistency | CRITICAL |
| **`so` and `soitem` are Full Refresh hourly** on Redshift | 2 large tables | Expensive, unnecessary — already Incremental on Snowflake | CRITICAL |
| **`sales_order` Full Refresh hourly** on Redshift | 1 large table | Same as above — Incremental on Snowflake | CRITICAL |
| **`part`, `product` Full Refresh hourly** on Redshift | 2 large tables | Same — should be Incremental | CRITICAL |
| **14 small tables Full Refresh every hour** | `kititem`, `objecttoobject`, `vendor`, `vendorparts`, `tag`, etc. | Unnecessary overhead — 6h or daily is fine | MEDIUM |
| **3 dated/legacy Magento tables** | `cms_block_23_july_2024_jr_stage`, `cms_page_23_july_2024_*` | Dead weight | CRITICAL |
| **PII in customer_entity** | `customer_entity` CDC | No masking — password_hash reaches Gold | CRITICAL |

### 2.3 Snowflake View Code Quality

Issues found in the 17 hand-crafted views:

| Issue | Severity | Examples |
|-------|----------|---------|
| **Hardcoded attribute IDs** | HIGH | `attribute_id = 677` (manufacturer), `= 681` (projectile), `= 649` (unit_type), etc. |
| **`SELECT *`** | HIGH | `Test1 AS (SELECT * FROM catalog_product_entity_int)` |
| **No CDC filter** | HIGH | No `_ab_cdc_deleted_at IS NULL` — includes deleted records |
| **Portuguese comments/aliases** | MEDIUM | `"Inicio da Hora"`, `PRODUTOFISH`, `PRODUTO_MAGENTO`, `CHAVE` |
| **Inconsistent schema references** | HIGH | `AD_FISHBOWL`, `AD_MAGENTO`, `AIRBYTE_SCHEMA`, `TEST_DTO`, `AD_REALTIME` — 5 different schemas |
| **Cross-database dependency** | HIGH | `PC_FIVETRAN_DB.UPS_INVOICE_HISTORY.UPS_INVOICE` — legacy Fivetran |
| **`DATEADD(day, -4, CURRENT_DATE())`** | MEDIUM | Realtime views only look back 4 days — any gap means data loss |
| **No tests or documentation** | HIGH | Zero tests, zero docs, zero freshness checks |
| **Duplicate view definitions** | HIGH | `F_SALES_REALTIME` defined twice (in `AD_REALTIME` AND `AD_MAGENTO`) with different logic |
| **`TEST_DTO` schema naming** | LOW | Schema named "TEST" suggests temporary, but it's used in production |

### 2.4 Power BI Data Freshness Issues

| Dataflow | Status | Impact |
|----------|--------|--------|
| **Data Warehouse** (old Snowflake) | Last refresh 12/31/25 (almost 2 months stale) | CLIENT ANALYSIS, SALES OVERVIEW, CROSSELING, SHIPPING ANALYSIS, INVENTORY, AFFILIATEUPDATE all stale |
| **Data Warehouse Redshift** (new) | Refreshing daily | REDSHIFT reports are current — this is the active path |
| Warning icons on 3+ reports | SHIPPING ANALYSIS, AFFILIATEUPDATE, LISTRAK OVERVIEW | Broken refresh — likely connection or query errors |

### 2.5 Fivetran Legacy Dependency

- `d_user` table comes from `PC_FIVETRAN_DB.MAGENTO_MYSQL_AMMUNITIONDEPOT_PROD2`
- This is a separate Snowflake account (`fcjoyo-isb82332.snowflakecomputing.com`)
- No other data comes from Fivetran — this is a single-table orphan dependency
- `UPS_INVOICE` is also referenced from this Fivetran database in Snowflake views

---

## 3. Improvement Plan — Phased Approach

### Phase 0: Triage & Stop the Bleeding (Week 1) -- COMPLETED 2026-02-26

**Goal:** Remove active risks without changing what Power BI sees.

| # | Action | Status |
|---|--------|--------|
| 0.1 | **Decommission FB→RS (so+soitem) connection** — 3 duplicate streams removed | DONE |
| 0.2 | **Remove 5 duplicate streams from MGT→RS (SALES)** — amasty_* (4) + magento_image_optimizer | DONE |
| 0.3 | **Remove 3 dated CMS tables** from Magento→Redshift — confirmed unused (not in Power BI or Snowflake views) | DONE |
| 0.4 | **Migrate `so`, `soitem` to Incremental+Dedup** on Redshift | DONE |
| 0.5 | **Migrate `sales_order` to Incremental+Dedup** on Redshift | DONE |
| 0.6 | **Migrate `part`, `product` to Incremental+Dedup** on Redshift | DONE |
| 0.7 | **Split 16 Full Refresh tables into separate 6h connection** (FB→RS: Full Refresh Light) | DONE |

**Streams in FB→RS: Full Refresh Light (every 6 hours):**
`kititem`, `objecttoobject`, `objecttoobjecttype`, `partcost`, `parttotracking`, `parttracking`, `postpo`, `postpoitem`, `receipt`, `receiptitem`, `tag`, `tagserialview`, `uomconversion`, `upsview_ad_a`, `vendor`, `vendorparts`

**Note:** `tagserialview` and `upsview_ad_a` have no primary key — must stay Full Refresh. `location` and `plugininfo` are already Incremental and remain in the main 1h connection.

**Result:** 8 connections → 7 connections. `so`/`soitem`/`sales_order`/`part`/`product` migrated from Full Refresh to Incremental. 16 slow-changing tables moved to 6h cycle. ~50% reduction in Airbyte compute on Redshift.

### Phase 1: Catalog & Map What Power BI Actually Uses (Week 2)

**Goal:** Create a complete inventory of what each Power BI report/dataflow uses, so we know what can safely be changed.

| # | Action | Output |
|---|--------|--------|
| 1.1 | **Audit each Power BI report** — document every table/column reference per report | `docs/POWERBI_DEPENDENCY_MAP.md` |
| 1.2 | **Compare Snowflake views vs dbt Gold outputs** — column-by-column, logic-by-logic | `docs/VIEW_COMPARISON_MATRIX.md` |
| 1.3 | **Identify stale/dead reports** — reports that haven't been viewed in 30+ days | List for decommission |
| 1.4 | **Document the "Data Warehouse" (old Snowflake) dataflow** — confirm if it can be turned off (last refresh 12/31/25) | Decision: decommission or fix |
| 1.5 | **Add dbt exposures** for all active Power BI reports (L8 from audit backlog) | `models/gold/_exposures.yml` |

### Phase 2: Consolidate Processing to a Single Path (Weeks 3-5)

**Goal:** Bring the Snowflake-only views into dbt so everything is governed, tested, and version-controlled.

#### 2A: Migrate Snowflake views that have NO dbt equivalent

| View | Target dbt Model | Complexity | Notes |
|------|-----------------|------------|-------|
| `F_COHORT` | `models/gold/f_cohort.sql` | MEDIUM | Cohort analysis — new dbt model |
| `F_COHORTDETAILED` | `models/gold/f_cohort_detailed.sql` | MEDIUM | Detailed cohort — new dbt model |
| `D_USER` | `models/gold/d_user.sql` | LOW | Needs Magento `admin_user` source (already in Airbyte) |
| `F_SALES_REALTIME` | `models/gold/f_sales_realtime.sql` | HIGH | 4-day window, Fishbowl↔Magento cost matching |
| `F_SALES_REALTIME_LASTDAYS` | `models/gold/f_sales_realtime_lastdays.sql` | HIGH | Extended version of above with freight allocation |
| `D_PRODUCT_REALTIME` | `models/gold/d_product_realtime.sql` | MEDIUM | EAV + Fishbowl cost enrichment |
| `D_CUSTOMERUPDATED` | Already exists as `magento_d_customerupdated.sql` | LOW | Just needs cleanup (H1 from backlog) |
| `INVENTORYCONVERSION` | Merge into `d_product_bundle.sql` or new model | LOW | SKU ↔ Part conversion table |

#### 2B: Reconcile dbt Gold vs Snowflake view duplicates

For each entity that exists in both places, we need to:
1. Compare output columns and row counts
2. Identify logic differences (especially cost calculation)
3. Choose the canonical version (usually dbt, unless Snowflake version is more correct)
4. Update Power BI dataflow to point to the single source

| Entity | Recommended Source | Action |
|--------|-------------------|--------|
| f_sales (historical) | dbt Gold | Keep as-is |
| f_sales (realtime) | NEW dbt model `f_sales_realtime` | Migrate Snowflake view logic into dbt |
| d_product | dbt Gold | Verify all columns match, add any missing attributes |
| d_customer_segmentation | dbt Gold | Verify cohort logic matches |
| f_shippment | dbt Gold | Compare and document differences |
| d_store | dbt Gold | Compare |
| d_vendor | dbt Gold | Compare |
| f_inventoryview | dbt Gold | Compare |
| f_pos | dbt Gold | Compare |

#### 2C: Migrate Fivetran dependency

| # | Action |
|---|--------|
| 2C.1 | Add `admin_user` to Magento Airbyte source (replace Fivetran d_user) |
| 2C.2 | Add `ups_invoice` to Fishbowl Airbyte source or replicate separately |
| 2C.3 | Once migrated, decommission Fivetran connection |

### Phase 3: Unify the Serving Layer (Weeks 5-7)

**Goal:** One dataflow per purpose, one source of truth per entity.

#### Target Architecture

```
                          ┌─────────────────────┐
     Fishbowl ──┐        │     SNOWFLAKE        │
                 │ Airbyte│  ┌───────────────┐   │
     Magento  ──┼────────►│  │ Bronze (raw)  │   │
                 │        │  └───────┬───────┘   │
     UPS Inv  ──┘        │          │ dbt       │
                          │  ┌───────▼───────┐   │
                          │  │ Silver (views) │   │
                          │  └───────┬───────┘   │
                          │          │ dbt       │
                          │  ┌───────▼───────┐   │        ┌─────────────┐
                          │  │  Gold (tables) │───────────►│  Power BI   │
                          │  └───────────────┘   │        │  Dataflows  │
                          └─────────────────────┘        └──────┬──────┘
                                                                │
                                                         ┌──────▼──────┐
                                                         │  Power BI   │
                                                         │  Reports    │
                                                         └─────────────┘
```

#### Target Dataflows (consolidated)

| Dataflow | Source | Contents | Frequency |
|----------|--------|----------|-----------|
| **Core Data Warehouse** | Snowflake Gold schema | f_sales, d_product, d_customer_segmentation, d_store, d_vendor, d_product_bundle, f_pos, f_inventoryview, f_shippment, f_cohort, f_cohort_detailed, d_user | Scheduled (every 1-3h) |
| **Realtime Sales** | Snowflake Gold schema | f_sales_realtime, d_product_realtime | Every 15-30 min |

**Decommission:**
- "Data Warehouse" (old Snowflake — stale since 12/31/25)
- "Data Warehouse Redshift" (replaced by unified Snowflake path)
- Fivetran connection (replaced by Airbyte sources)
- All `TEST_DTO.*` views (replaced by dbt models)
- All `AD_REALTIME.*` views (replaced by dbt models)
- All `AIRBYTE_SCHEMA.*` ad-hoc views (replaced by dbt models)

### Phase 4: Add Observability & Guardrails (Weeks 7-9)

| # | Action | Tool |
|---|--------|------|
| 4.1 | **Source freshness monitoring** | dbt source freshness + alerts |
| 4.2 | **dbt test alerts on failure** | dbt Cloud + Slack/email notifications |
| 4.3 | **Airbyte sync monitoring** | Airbyte alerts on sync failure |
| 4.4 | **Power BI refresh monitoring** | Power BI Admin API or manual checks |
| 4.5 | **Data quality anomaly detection** | Elementary or dbt_expectations anomaly tests |
| 4.6 | **CI pipeline for PRs** | dbt build + slim CI on pull requests (T3 from backlog) |
| 4.7 | **End-to-end lineage dashboard** | dbt exposures + dbt docs generate |

### Phase 5: Complete Snowflake Migration (Weeks 9-12)

| # | Action |
|---|--------|
| 5.1 | Switch dbt adapter from `dbt-redshift` to `dbt-snowflake` |
| 5.2 | Run full dbt build on Snowflake to validate |
| 5.3 | Update Power BI dataflows to point to Snowflake Gold schema exclusively |
| 5.4 | Decommission Redshift cluster |
| 5.5 | Remove all Airbyte → Redshift connections |

---

## 4. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Power BI report breaks during migration | HIGH | HIGH | Phase 1 dependency map; change one dataflow at a time; keep old dataflow as fallback |
| Snowflake view cost logic differs from dbt | HIGH | HIGH | Column-by-column comparison in Phase 2B before switching |
| Realtime views (4-day window) lose data during cutover | MEDIUM | HIGH | Run both paths in parallel for 1 week before switching |
| Fivetran decommission breaks d_user/UPS reports | LOW | MEDIUM | Migrate to Airbyte first, validate, then cut |
| dbt Cloud Snowflake runs take longer than Redshift | LOW | LOW | Performance test in Phase 5.2 before switching prod |

---

## 5. Quick Reference — What Lives Where Today

### Snowflake Schemas

| Schema | Purpose | Owner | Status |
|--------|---------|-------|--------|
| `AD_FISHBOWL` | Airbyte raw Fishbowl data | AIRBYTE_ROLE | Active — ingestion |
| `AD_MAGENTO` | Airbyte raw Magento data | AIRBYTE_ROLE | Active — ingestion |
| `AIRBYTE_SCHEMA` | Mix of raw Airbyte + hand-written views | AIRBYTE_ROLE | Needs cleanup — views should move to Gold |
| `AD_REALTIME` | Hand-written realtime views | Unknown | Needs cleanup — views should move to dbt |
| `TEST_DTO` | Hand-written analytical views | Unknown | Needs cleanup — name implies temp, used in prod |
| `SILVER` | dbt Silver models (future) | TRANSFORMER_ROLE | Provisioned, not yet active |
| `GOLD` | dbt Gold models (future) | TRANSFORMER_ROLE | Provisioned, not yet active |

### Redshift Schemas

| Schema | Purpose | Status |
|--------|---------|--------|
| `fishbowl` | Airbyte raw Fishbowl data | Active (production) |
| `magento` | Airbyte raw Magento data | Active (production) |
| `silver` | dbt Silver views | Active (production) |
| `gold` | dbt Gold tables | Active (production) — **this is the canonical Gold today** |
| `dbt_dev` | Developer sandbox | Active |

---

## 6. Decision Log (for discussion)

| # | Decision Needed | Options | Recommendation |
|---|----------------|---------|----------------|
| D1 | **Where should dbt production run?** | A) Keep Redshift until full migration; B) Switch to Snowflake now | **A** — Redshift is stable. Switch when Snowflake is fully validated. |
| D2 | **What to do with stale "Data Warehouse" dataflow?** | A) Fix it; B) Decommission it | **B** — The REDSHIFT versions of all reports are active. The old dataflow is dead. |
| D3 | **Should realtime views stay as Snowflake views or become dbt models?** | A) Keep as views (faster iteration); B) Migrate to dbt (governance) | **B** — They contain critical business logic (cost, freight) that needs testing. |
| D4 | **How to handle UPS Invoice dependency?** | A) Add UPS Invoice to Airbyte; B) Keep Fivetran for this one table | **A** — Eliminate the Fivetran dependency entirely. |
| D5 | **Should the f_sales test* columns be added to dbt?** | A) Yes (preserve); B) No (let them drop) | **Depends on D1 of AUDIT_BACKLOG.md** — need Power BI team confirmation first. |
| D6 | **Naming for Snowflake schemas** | A) Keep TEST_DTO; B) Rename to proper names | **B** — Rename to `GOLD` (dbt models) once migration is complete. |

---

## Appendix A: Airbyte Connections — Current State (post Phase 0)

### Redshift

| Connection | Streams | Frequency | Sync Mode | Notes |
|------------|---------|-----------|-----------|-------|
| **FB→RS: Incremental Critical** | 18 streams | 1 hour | Incremental + Dedup | `so`, `soitem`, `part`, `product` migrated from Full Refresh. `location`, `plugininfo` already Incremental. |
| **FB→RS: Full Refresh Light** | 16 streams | 6 hours | Full Refresh + Overwrite | Slow-changing tables. `tagserialview`, `upsview_ad_a` have no PK. |
| **MGT→RS (SALES)** | 1 stream | 1 hour | Incremental + Dedup | `sales_order` only. 5 duplicate streams removed. |
| **MGT→RS (CATALOG)** | 1 stream | 1 hour | Full Refresh + Overwrite | `catalog_product_entity` |
| **MGT→RS (main)** | ~20 streams | 1 hour | Incremental + Dedup | Production — well configured |

### Snowflake

| Connection | Streams | Frequency | Sync Mode | Notes |
|------------|---------|-----------|-----------|-------|
| **FB→SF** | 13 streams | Cron | Incremental + Dedup / Full Refresh | Well configured — no changes needed |
| **MGT→SF (SO e SOI)** | 18 streams | Cron | Incremental + Dedup / Full Refresh | Well configured — no changes needed |

### Decommissioned

| Connection | Action | Date |
|------------|--------|------|
| FB→RS (so+soitem) | Deleted — 3 duplicate streams | 2026-02-26 |
| 5 duplicate streams in MGT→RS (SALES) | Disabled | 2026-02-26 |
| 3 dated CMS tables in MGT→RS (main) | Disabled | 2026-02-26 |

### Legacy (still active)

| Connection | Notes |
|------------|-------|
| Fivetran → PC_FIVETRAN_DB | `d_user` and `UPS_INVOICE` — pending migration to Airbyte (Phase 2C) |

---

## Appendix B: Snowflake Views → dbt Model Mapping

| Snowflake View | Schema | Equivalent dbt Model | Migration Action |
|----------------|--------|---------------------|-----------------|
| `D_CUSTOMERUPDATED` | AD_REALTIME | `magento_d_customerupdated` (Silver) | Cleanup existing model (H1) |
| `D_PRODUCT_REALTIME` | AD_REALTIME | NEW `d_product_realtime` (Gold) | Create new — EAV + Fishbowl cost |
| `F_SALES_REALTIME` | AD_REALTIME | NEW `f_sales_realtime` (Gold) | Create new — 4-day window, configurable cost logic |
| `F_SALES_REALTIME_LASTDAYS` | AD_REALTIME | NEW `f_sales_realtime_lastdays` (Gold) | Create new — extended sales with freight |
| `F_SALES_REALTIME` | AD_MAGENTO | Same as above (duplicate view!) | Delete after migration |
| `F_COHORT` | TEST_DTO | NEW `f_cohort` (Gold) | Create new |
| `F_COHORTDETAILED` | TEST_DTO | NEW `f_cohort_detailed` (Gold) | Create new |
| `D_PRODUCT` | TEST_DTO | `d_product` (Gold) — already exists | Compare columns, add missing |
| `INVENTORYCONVERSION` | TEST_DTO | `d_product_bundle` (Gold) — partial overlap | Extend existing or create new |
| `D_VENDOR` | AIRBYTE_SCHEMA | `d_vendor` (Gold) — already exists | Compare and document |
| `F_INVENTORYVIEW` | AIRBYTE_SCHEMA | `f_inventoryview` (Gold) — already exists | Compare and document |
| `F_SHIPPMENT` | TEST_DTO | `f_shippment` (Gold) — already exists | Compare and document |
| `D_STORE` | TEST_DTO | `d_store` (Gold) — already exists | Compare and document |
| `D_USER` | PC_FIVETRAN_DB | NEW `d_user` (Gold) | Create from `admin_user` source |
| `D_CUSTOMERSEGMENTATION` | TEST_DTO | `d_customer_segmentation` (Gold) — already exists | Compare RFM logic |
| `D_CUSTOMERUPDATED` | TEST_DTO | Same as AD_REALTIME version (duplicate!) | Delete after migration |
| `F_POS` | AIRBYTE_SCHEMA | `f_pos` (Gold) — already exists | Compare and document |
