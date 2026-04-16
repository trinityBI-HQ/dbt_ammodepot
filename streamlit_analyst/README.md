# Cortex Analyst Chatbot

Natural language query interface for Ammunition Depot's Gold layer, powered by Snowflake Cortex Analyst. Deployed as a Streamlit in Snowflake (SiS) app on container runtime.

## Architecture

```mermaid
flowchart TD
    subgraph Users
        OPS[Operations Team]
        EXEC[Executive / Ownership]
    end

    subgraph SiS["Streamlit in Snowflake (Container Runtime)"]
        APP["streamlit_app.py<br/>AD_ANALYTICS.OPS.ANALYST"]
        TOKEN["/snowflake/session/token<br/>OAuth auto-injected"]
        APP -->|read| TOKEN
    end

    subgraph Cortex["Snowflake Cortex"]
        API["REST API<br/>/api/v2/cortex/analyst/message"]
        SV["Semantic View<br/>AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST"]
        API -->|reads| SV
    end

    subgraph Gold["AD_ANALYTICS.GOLD"]
        FS[f_sales]
        FI[f_inventoryview]
        FP[f_pos]
        DP[d_product]
        DV[d_vendor]
        DCS[d_customer_segmentation]
    end

    subgraph Compute
        WH["COMPUTE_WH<br/>(XSMALL)"]
    end

    OPS -->|ask question| APP
    EXEC -->|ask question| APP
    APP -->|POST + Bearer token| API
    API -->|generates SQL| WH
    WH -->|queries| Gold
    SV -.->|defines schema for| FS
    SV -.->|defines schema for| FI
    SV -.->|defines schema for| FP
    SV -.->|defines schema for| DP
    SV -.->|defines schema for| DV
    SV -.->|defines schema for| DCS
    WH -->|results| APP
    APP -->|renders answer| Users
```

## Data Flow (Sequence)

```mermaid
sequenceDiagram
    participant User
    participant Streamlit as Streamlit App
    participant Cortex as Cortex Analyst API
    participant SV as Semantic View
    participant WH as COMPUTE_WH

    User->>Streamlit: "What is total revenue today?"
    Streamlit->>Streamlit: Read /snowflake/session/token
    Streamlit->>Cortex: POST /api/v2/cortex/analyst/message
    Cortex->>SV: Resolve tables, columns, metrics
    Cortex-->>Streamlit: { text, sql, suggestions }
    Streamlit->>WH: Execute generated SQL
    WH-->>Streamlit: Query results (DataFrame)
    Streamlit-->>User: Answer + SQL + follow-up suggestions
```

## Semantic View Coverage

```mermaid
erDiagram
    F_SALES ||--o{ D_PRODUCT : "PRODUCT_ID"
    F_SALES ||--o{ D_VENDOR : "VENDOR → vendor_id"
    F_SALES ||--o{ D_CUSTOMER_SEGMENTATION : "RANK_ID"
    F_POS ||--o{ D_VENDOR : "vendor_id"
    F_POS ||--o{ D_PRODUCT : "part_number → SKU"
    F_INVENTORYVIEW ||--o{ D_PRODUCT : "part_number → SKU"

    F_SALES {
        number ROW_TOTAL "Revenue per line item"
        number COST "COGS per line item"
        number QTY_ORDERED "Units sold"
        number FREIGHT_REVENUE "Shipping revenue"
        number FREIGHT_COST "Shipping cost"
        timestamp CREATED_AT "Order date (EDT)"
        varchar STATUS "COMPLETE, PROCESSING, etc."
        varchar STOREFRONT "Website or GunBroker"
    }

    F_INVENTORYVIEW {
        varchar part_number "SKU identifier"
        number qty_available "Units in stock"
        number qty_on_order "Units on open POs"
        number extended_cost "Inventory valuation"
    }

    F_POS {
        number qty "Quantity received"
        number unit_cost "PO unit cost"
        number precise_leadtime "Best lead time estimate"
        date datereceived "Receipt date"
        date po_created_at "PO creation date"
    }

    D_PRODUCT {
        varchar SKU "Stock keeping unit"
        varchar MANUFACTURER "Brand name"
        varchar CALIBER "Ammunition caliber"
        varchar USE_TYPE_CATEGORY "Hunting, Tactical, etc."
        number AVGCOST "Average cost"
    }

    D_VENDOR {
        varchar vendor_name "Supplier name"
        number lead_time_days "Default lead time"
        number credit_limit "Vendor credit limit"
    }

    D_CUSTOMER_SEGMENTATION {
        varchar CUSTOMER_CLASSIFICATION "16 RFM segments"
        varchar CUSTOMER_GROUP "Law Enforcement, Wholesale, etc."
        number TOTAL_REVENUE "12-month revenue"
        number DAYS_SINCE_LAST_PURCHASE "Recency metric"
    }
```

## Deployment

| Attribute | Value |
|-----------|-------|
| **Snowflake Object** | `AD_ANALYTICS.OPS.ANALYST` |
| **Runtime** | Container (`SYSTEM$ST_CONTAINER_RUNTIME_PY3_11`) |
| **Compute Pool** | `sales_dashboard_pool` (shared, CPU_X64_XS) |
| **Query Warehouse** | `COMPUTE_WH` (XSMALL) |
| **Semantic View** | `AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST` |
| **CI/CD** | GitHub Actions (`deploy-streamlit-analyst.yml`) |
| **Auth** | `/snowflake/session/token` (container runtime OAuth) |

### RBAC

| Role | Access |
|------|--------|
| `TRANSFORMER_ROLE` | Owns semantic view |
| `STREAMLIT_ROLE` | Owns Streamlit app object |
| `DASHBOARD_VIEWER_ROLE` | USAGE on app + semantic view |
| `POWERBI_READONLY_ROLE` | USAGE on app + semantic view |

### Cost Estimate

| Component | Monthly Cost |
|-----------|-------------|
| Cortex Analyst messages | ~$15-50 (6.7 credits / 100 messages) |
| COMPUTE_WH SQL execution | Negligible (shared XSMALL) |
| Compute pool | $0 incremental (shared) |
| **Total** | **~$15-50/mo** |

## Project Structure

```
streamlit_analyst/
├── README.md                  # This file
├── streamlit_app.py           # Entry point (SiS)
├── app.py                     # Entry point (local dev)
├── snowflake.yml              # SiS definition v2
├── requirements.txt           # streamlit, requests, pandas, snowflake-snowpark-python
├── setup/
│   ├── 01_bootstrap.sql       # Semantic view DDL + RBAC grants
│   └── 02_verified_queries.sql # Golden question SQL for accuracy
└── utils/
    ├── __init__.py
    ├── analyst.py             # Cortex Analyst REST API wrapper
    ├── db.py                  # Snowpark session + query runner
    └── chart_theme.py         # Dark theme constants (subset)
```

## Semantic View Tables (Phase 1)

| Gold Model | Type | Semantic Role | Key Questions |
|---|---|---|---|
| `f_sales` | Fact (incremental) | Revenue, orders, margins | "Total revenue today", "Top products this week" |
| `f_inventoryview` | Fact (table) | Stock levels, valuation | "How many units of 9mm in stock?" |
| `f_pos` | Fact (table) | Purchase orders, lead times | "Which vendors are late?", "Open POs" |
| `d_product` | Dimension | Product catalog, taxonomy | "List Hornady products", "Revenue by use-type" |
| `d_vendor` | Dimension | Supplier master | "Vendor lead times", "Credit limits" |
| `d_customer_segmentation` | Dimension | RFM segments | "At-Risk customers", "Segment counts" |

## Verified Queries (Golden Question Set)

| # | Question | Pass Criteria |
|---|----------|--------------|
| 1 | "What is total revenue today?" | Matches Streamlit Page 1 Net Sales KPI |
| 2 | "What is our gross margin this month?" | Matches Page 1 Margin % |
| 3 | "Top 10 products by revenue this week" | Correct SKUs and ordering |
| 4 | "How many units of 9mm are in stock?" | Matches Page 3 inventory filter |
| 5 | "Which vendors have the longest lead times?" | Matches Page 3 Vendor Analysis |
| 6 | "Total orders yesterday vs day before" | Matches Page 1 delta |
| 7 | "Revenue by category this month" | Matches Page 2 category breakdown |
| 8 | "How many customers are At-Risk Regular?" | Correct count from d_customer_segmentation |
| 9 | "Show me open POs not yet received" | Matches Page 3 Open POs tab |
| 10 | "Top 5 manufacturers by units sold MTD" | Matches Page 2 manufacturer chart |

## Local Development

```bash
# From repo root
cd streamlit_analyst

# Set environment variables (same as ammodepot/.env)
export SNOWFLAKE_ACCOUNT="your_account"
export SNOWFLAKE_USER="your_user"
export SNOWFLAKE_PRIVATE_KEY_PATH="../ammodepot/.ssh/snowflake_key.p8"
export SNOWFLAKE_PRIVATE_KEY_PASSPHRASE="your_passphrase"

# Run locally
streamlit run app.py
```

## AI Roadmap Status

```mermaid
flowchart LR
    P1["Phase 1 ✅<br/>Text-to-SQL Chatbot<br/>Cortex Analyst<br/>2026-04-14"]
    P2["Phase 2 ✅<br/>Demand Forecasting<br/>ML.FORECAST<br/>2026-04-14"]
    P3["Phase 3 ✅<br/>Anomaly Alerts<br/>ML.ANOMALY_DETECTION<br/>2026-04-14"]
    P4["Phase 4 ✅<br/>Churn Narratives<br/>CORTEX.COMPLETE<br/>2026-04-16"]
    P5["Phase 5 ✅<br/>Reorder Intelligence<br/>F_REORDER_RECOMMENDATIONS<br/>2026-04-16"]

    P1 -->|foundation proven| P2
    P2 -->|forecasts reliable| P3
    P3 -->|monitoring active| P4
    P4 -->|narratives trusted| P5

    style P1 fill:#2d6a4f,stroke:#40916c,color:#fff
    style P2 fill:#2d6a4f,stroke:#40916c,color:#fff
    style P3 fill:#2d6a4f,stroke:#40916c,color:#fff
    style P4 fill:#2d6a4f,stroke:#40916c,color:#fff
    style P5 fill:#2d6a4f,stroke:#40916c,color:#fff
```

All phases are Snowflake-native — no external LLM APIs.

## References

- [Cortex Analyst REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/rest-api)
- [Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic/overview)
- [Semantic View YAML Spec](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-view-yaml-spec)
- [Best Practices for Semantic Views](https://www.snowflake.com/en/developers/guides/best-practices-semantic-views-cortex-analyst/)
- Brainstorm: `.claude/sdd/features/BRAINSTORM_CORTEX_ANALYST_CHATBOT.md`
