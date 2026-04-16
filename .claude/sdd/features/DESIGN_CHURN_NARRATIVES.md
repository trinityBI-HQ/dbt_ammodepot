# DESIGN: Customer Churn Narratives with CORTEX.COMPLETE

> Technical design for Page 5 "Customer Intelligence" — segment health dashboard with LLM executive summary

## Metadata

| Attribute | Value |
|-----------|-------|
| **Feature** | CHURN_NARRATIVES |
| **Date** | 2026-04-15 |
| **Author** | design-agent |
| **DEFINE** | [DEFINE_CHURN_NARRATIVES.md](./DEFINE_CHURN_NARRATIVES.md) |
| **Status** | Ready for Build |

---

## Architecture Overview

```text
┌───────────────────────────────────────────────────────────────────┐
│  Streamlit Sales Dashboard (SiS container runtime)                │
│  AD_ANALYTICS.OPS.SALES_DASHBOARD                                 │
│                                                                   │
│  Pages 1-4 (unchanged)                                            │
│                                                                   │
│  Page 5: Customer Intelligence (NEW)                              │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ Executive Summary Banner (CORTEX.COMPLETE)            │   │ │
│  │  │ cached 10 min, graceful fallback on error             │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                              │ │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                       │ │
│  │  │ KPI  │ │ KPI  │ │ KPI  │ │ KPI  │  (4 cards)            │ │
│  │  └──────┘ └──────┘ └──────┘ └──────┘                       │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ Segment Health Table (17 rows, dark_dataframe)        │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ Segment Distribution Chart (horizontal bar, Plotly)   │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐   │ │
│  │  │ Top At-Risk Customers Table (10 rows, dark_dataframe) │   │ │
│  │  └──────────────────────────────────────────────────────┘   │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Shared utils/ (unchanged)                                        │
│  ├── db.py          → run_query()                                 │
│  └── chart_theme.py → apply_theme(), dark_dataframe(), constants  │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────────────┐
│  Snowflake (AD_ANALYTICS.GOLD)                                    │
│                                                                   │
│  D_CUSTOMER_SEGMENTATION ──→ segment_summary SQL (aggregation)    │
│                           ──→ top_at_risk SQL (filter + sort)     │
│                           ──→ CORTEX.COMPLETE (LLM summary)       │
│                                                                   │
│  No new tables, views, or models created.                         │
└───────────────────────────────────────────────────────────────────┘
```

---

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| `5_Customer_Intelligence.py` | Page 5 rendering — queries, KPIs, tables, chart, LLM banner | Streamlit + Plotly + SQL |
| `run_query()` | Execute SQL against Snowflake (dual-mode SiS/local) | Existing `utils/db.py` |
| `dark_dataframe()` | Render tables in dark theme | Existing `utils/chart_theme.py` |
| `apply_theme()` | Style Plotly charts | Existing `utils/chart_theme.py` |
| `CORTEX.COMPLETE` | Generate executive summary from structured data | Snowflake Cortex LLM (`gemini-2-5-flash`) |

---

## Key Decisions

### Decision 1: Single File, No New Utils

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Page 5 needs SQL queries, KPI rendering, table rendering, chart rendering, and LLM integration. Could split into a separate `utils/intelligence.py` or keep self-contained.

**Choice:** Single file `5_Customer_Intelligence.py` with all logic inline. Constants (model name, segment lists) as module-level variables at the top.

**Rationale:** Pages 1-4 follow this pattern — each is self-contained with queries and rendering inline. A 400-500 line file is consistent with Page 4 (Forecast, ~330 lines). No shared utility is needed because the LLM call is specific to this page.

**Alternatives Rejected:**
1. `utils/intelligence.py` — premature abstraction; no other page needs these queries
2. `utils/cortex.py` — only one CORTEX.COMPLETE call in the entire app; not worth a module

**Consequences:**
- Easy to understand — one file to read
- If a second page needs CORTEX.COMPLETE, extract then (YAGNI)

---

### Decision 2: SQL-Side Aggregation, Python-Side Prompt Assembly

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** The CORTEX.COMPLETE prompt needs segment counts and values. Could aggregate in SQL and pass to LLM in SQL (single query), or aggregate in SQL, build the prompt in Python, and call LLM in a separate query.

**Choice:** Two-step: (1) SQL aggregation returns a DataFrame, (2) Python formats the DataFrame into a prompt string, (3) separate SQL query calls `CORTEX.COMPLETE` with the assembled prompt.

**Rationale:** Separating aggregation from LLM call means:
- The aggregation result is reusable (KPI cards + tables + prompt all share it)
- The prompt is readable and maintainable in Python (not buried in SQL concatenation)
- Cache can be independent — aggregation cached 10 min, LLM cached 10 min
- Debugging is easier — can inspect the prompt before sending

**Alternatives Rejected:**
1. Single SQL query with inline aggregation + CORTEX.COMPLETE — prompt unreadable in SQL, can't reuse aggregation
2. All Python with Snowpark DataFrame API — deviates from `run_query()` pattern used everywhere else

**Consequences:**
- Two SQL round-trips per cache miss (aggregation + LLM call) — negligible latency impact
- Prompt template is a Python f-string — easy to iterate on

---

### Decision 3: Segment Categorization as Constants

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Need to classify which of the 17 segments are "concerning" vs "positive" for KPI calculations and the at-risk table.

**Choice:** Define two sets as module-level constants:

```python
CONCERNING_SEGMENTS = {
    "At-Risk Regular", "Lost Buyer", "Inactive",
    "Inactive Regular", "Lapsed Buyer", "Losing 1-Time Buyer",
}
POSITIVE_SEGMENTS = {
    "Super Engaged", "Highly Engaged", "Active Loyalist",
    "Engaged Regular", "New Buyer", "New Active Buyer",
}
```

**Rationale:** These classifications come from the `d_customer_segmentation` model's CASE logic. They're stable (defined in dbt SQL). Hardcoding them as constants is simpler and faster than a SQL lookup, and matches how Page 1 hardcodes `DEFAULT_STATUSES`.

**Alternatives Rejected:**
1. dbt seed table for segment categories — overhead for 17 static values
2. SQL CASE in every query — duplicates logic, harder to maintain

**Consequences:**
- If a new classification is added to `d_customer_segmentation`, this constant must be updated manually
- The `Unclassified` and remaining segments (Moderate Engager, Regular w/Potential, Relatively New Buyer, Nurture Potential) fall into neither set — they appear in the table but don't drive KPI counts

---

### Decision 4: LLM Model as Swappable Constant

| Attribute | Value |
|-----------|-------|
| **Status** | Accepted |
| **Date** | 2026-04-15 |

**Context:** Model choice (`gemini-2-5-flash`) may need to change if unavailable in region or if quality is insufficient.

**Choice:** Module-level constant `LLM_MODEL = "gemini-2-5-flash"` at the top of the file. One-line change to switch to fallback.

**Rationale:** No config file overhead for a single constant. Same pattern as other page-level constants (e.g., `DEFAULT_STATUSES` on Page 1).

---

## File Manifest

| # | File | Action | Purpose | Agent | Dependencies |
|---|------|--------|---------|-------|--------------|
| 1 | `streamlit_app/pages/5_Customer_Intelligence.py` | Create | Page 5 — KPI cards, segment table, at-risk table, distribution chart, LLM summary banner | @streamlit-expert | None (uses existing utils/) |

**Total Files:** 1

**Files NOT Modified:** `utils/db.py`, `utils/chart_theme.py`, Pages 1-4, `snowflake.yml`, `requirements.txt` (no new dependencies)

---

## Agent Assignment Rationale

| Agent | Files Assigned | Why This Agent |
|-------|----------------|----------------|
| @streamlit-expert | 1 | SiS container runtime expertise, Plotly `go.Figure` patterns, `dark_dataframe()` usage, dual-mode (local + SiS) |

---

## Code Patterns

### Pattern 1: Page Header (reuse from Pages 1-4)

```python
"""Customer Intelligence — Segment health and churn risk.

AI Roadmap Phase 4: CORTEX.COMPLETE executive summary + RFM segment dashboard.
Source: AD_ANALYTICS.GOLD.D_CUSTOMER_SEGMENTATION
"""

import base64
import pathlib

import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from utils.db import run_query
from utils.chart_theme import (
    apply_theme,
    dark_dataframe,
    BG_CHART,
    ACCENT,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
)

_logo_path = pathlib.Path(__file__).parents[1] / "AmmoDepot.png"
_logo_b64 = base64.b64encode(_logo_path.read_bytes()).decode()
if hasattr(st, "logo"):
    st.logo(str(_logo_path))

st.markdown(
    "<style>"
    "   .block-container {padding-left: 1rem; padding-right: 1rem; max-width: 100%;}"
    "   .stMainBlockContainer {max-width: 100%;}"
    "</style>",
    unsafe_allow_html=True,
)

st.markdown(
    f'<div style="display:flex;align-items:center;gap:12px;">'
    f'<img src="data:image/png;base64,{_logo_b64}" height="48">'
    f'<h1 style="margin:0;">CUSTOMER INTELLIGENCE</h1>'
    f'</div>',
    unsafe_allow_html=True,
)
```

### Pattern 2: Segment Summary Query

```python
# ── Constants ────────────────────────────────────────────────────────────────

LLM_MODEL = "gemini-2-5-flash"
LLM_CACHE_TTL = 600  # seconds — matches dbt build cadence

CONCERNING_SEGMENTS = {
    "At-Risk Regular", "Lost Buyer", "Inactive",
    "Inactive Regular", "Lapsed Buyer", "Losing 1-Time Buyer",
}
POSITIVE_SEGMENTS = {
    "Super Engaged", "Highly Engaged", "Active Loyalist",
    "Engaged Regular", "New Buyer", "New Active Buyer",
}


# ── Data Loading ─────────────────────────────────────────────────────────────

@st.cache_data(ttl="10m", show_spinner=False)
def load_segment_summary() -> pd.DataFrame:
    """Aggregate D_CUSTOMER_SEGMENTATION by classification."""
    return run_query("""
        SELECT
            CUSTOMER_CLASSIFICATION,
            COUNT(*)                              AS CUSTOMER_COUNT,
            COALESCE(SUM(TOTAL_REVENUE), 0)       AS TOTAL_LTV,
            COALESCE(AVG(DAYS_SINCE_LAST_PURCHASE), 0) AS AVG_DAYS_SILENT,
            COALESCE(AVG(NUMBER_OF_PURCHASES), 0) AS AVG_PURCHASES
        FROM D_CUSTOMER_SEGMENTATION
        GROUP BY CUSTOMER_CLASSIFICATION
        ORDER BY CUSTOMER_COUNT DESC
    """)
```

### Pattern 3: Top At-Risk Customers Query

```python
@st.cache_data(ttl="10m", show_spinner=False)
def load_top_at_risk(n: int = 10) -> pd.DataFrame:
    """Top N highest-value customers in concerning segments."""
    segments_sql = ", ".join(f"'{s}'" for s in CONCERNING_SEGMENTS)
    return run_query(f"""
        SELECT
            RANK_ID,
            CUSTOMER_CLASSIFICATION,
            TOTAL_REVENUE,
            DAYS_SINCE_LAST_PURCHASE,
            NUMBER_OF_PURCHASES,
            TOTAL_PURCHASES_ALL_TIME,
            FREQUENCY,
            RECENCY,
            CUSTOMER_GROUP
        FROM D_CUSTOMER_SEGMENTATION
        WHERE CUSTOMER_CLASSIFICATION IN ({segments_sql})
          AND TOTAL_REVENUE IS NOT NULL
        ORDER BY TOTAL_REVENUE DESC
        LIMIT {n}
    """)
```

### Pattern 4: CORTEX.COMPLETE Executive Summary with Graceful Fallback

```python
@st.cache_data(ttl=LLM_CACHE_TTL, show_spinner=False)
def generate_executive_summary(segment_json: str) -> str | None:
    """Call CORTEX.COMPLETE to generate executive summary.

    Returns None on any failure — caller renders fallback.
    """
    try:
        prompt = (
            "You are a data analyst writing a 3-4 sentence executive summary "
            "for operations managers at an ammunition retailer. "
            "Be numbers-forward and concise — no filler, no greetings, no caveats. "
            "Highlight concerning trends (growing at-risk segments, high-value customers going silent). "
            "Reference specific segment names and numbers from the data.\n\n"
            f"Customer segment data:\n{segment_json}"
        )
        # Escape single quotes in prompt for SQL safety
        safe_prompt = prompt.replace("'", "''")
        df = run_query(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                '{LLM_MODEL}',
                '{safe_prompt}'
            ) AS SUMMARY
        """)
        if not df.empty and df.iloc[0]["SUMMARY"]:
            return str(df.iloc[0]["SUMMARY"]).strip()
        return None
    except Exception:
        return None
```

### Pattern 5: KPI Cards (reuse Page 1 HTML pattern)

```python
def render_kpi_cards(df_segments: pd.DataFrame):
    """Render 4 KPI cards from segment summary data."""
    total_customers = int(df_segments["CUSTOMER_COUNT"].sum())
    at_risk_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"].isin(CONCERNING_SEGMENTS),
            "CUSTOMER_COUNT",
        ].sum()
    )
    lost_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"] == "Lost Buyer",
            "CUSTOMER_COUNT",
        ].sum()
    )
    positive_count = int(
        df_segments.loc[
            df_segments["CUSTOMER_CLASSIFICATION"].isin(POSITIVE_SEGMENTS),
            "CUSTOMER_COUNT",
        ].sum()
    )
    health_pct = (positive_count / total_customers * 100) if total_customers else 0

    cards = [
        {
            "icon": "&#x1F465;",
            "color": "#00B4D8",
            "title": "Total Customers",
            "value": f"{total_customers:,}",
        },
        {
            "icon": "&#x26A0;",
            "color": "#FF4B4B",
            "title": "At-Risk",
            "value": f"{at_risk_count:,}",
        },
        {
            "icon": "&#x274C;",
            "color": "#FF4B4B",
            "title": "Lost Buyers",
            "value": f"{lost_count:,}",
        },
        {
            "icon": "&#x2705;",
            "color": "#2DC653",
            "title": "Healthy Segments",
            "value": f"{health_pct:.1f}%",
        },
    ]
    # Reuse KPI card CSS from Page 1 (injected per-page)
    # ... (same HTML pattern as Page 1 kpi_cards)
```

### Pattern 6: Executive Summary Banner

```python
def render_summary_banner(summary: str | None):
    """Render the LLM executive summary as a styled banner."""
    if summary:
        st.markdown(
            f'<div style="background:#1a2733; border-left:4px solid {ACCENT}; '
            f'border-radius:8px; padding:16px 20px; margin-bottom:16px; '
            f'color:{TEXT_PRIMARY}; font-size:14px; line-height:1.6;">'
            f"{summary}</div>",
            unsafe_allow_html=True,
        )
    else:
        st.caption("Executive summary unavailable.")
```

### Pattern 7: Segment Distribution Chart (COULD — horizontal bar)

```python
def render_segment_chart(df_segments: pd.DataFrame):
    """Horizontal bar chart of customer count by segment."""
    df_sorted = df_segments.sort_values("CUSTOMER_COUNT", ascending=True)

    colors = [
        "#FF4B4B" if seg in CONCERNING_SEGMENTS
        else ACCENT if seg in POSITIVE_SEGMENTS
        else TEXT_SECONDARY
        for seg in df_sorted["CUSTOMER_CLASSIFICATION"]
    ]

    fig = go.Figure(
        go.Bar(
            x=df_sorted["CUSTOMER_COUNT"].tolist(),
            y=df_sorted["CUSTOMER_CLASSIFICATION"].tolist(),
            orientation="h",
            marker_color=colors,
            text=df_sorted["CUSTOMER_COUNT"].tolist(),
            textposition="outside",
            textfont=dict(color=TEXT_PRIMARY, size=11),
        )
    )
    apply_theme(fig, height=450, show_legend=False, margin=dict(l=0, r=40, t=10, b=0))
    fig.update_layout(
        xaxis_title="Customer Count",
        yaxis=dict(automargin=True),
    )
    st.plotly_chart(fig, use_container_width=True, key="seg_dist")
```

---

## Data Flow

```text
1. User navigates to Page 5 "Customer Intelligence"
   │
   ▼
2. load_segment_summary() — SQL aggregation of D_CUSTOMER_SEGMENTATION
   │  (cached 10 min via st.cache_data)
   │  Returns: DataFrame with 17 rows (one per classification)
   │
   ├──→ render_kpi_cards(df_segments) — compute totals, render 4 KPI cards
   │
   ├──→ render_segment_table(df_segments) — dark_dataframe() with fmt
   │
   ├──→ render_segment_chart(df_segments) — Plotly horizontal bar
   │
   └──→ Build prompt JSON from df_segments.to_json()
        │
        ▼
3. generate_executive_summary(segment_json) — CORTEX.COMPLETE call
   │  (cached 10 min via st.cache_data, separate from aggregation cache)
   │  Returns: string summary or None
   │
   ▼
4. render_summary_banner(summary) — HTML banner or fallback caption
   │
   ▼
5. load_top_at_risk(n=10) — SQL query filtered to concerning segments
   │  (cached 10 min)
   │
   ▼
6. render_at_risk_table(df_at_risk) — dark_dataframe() with fmt
```

**Execution order in the page file:**

```python
# 1. Load data (all cached)
df_segments = load_segment_summary()
df_at_risk = load_top_at_risk()

# 2. Generate LLM summary (cached, may return None)
segment_json = df_segments.to_json(orient="records")
summary = generate_executive_summary(segment_json)

# 3. Render (top-to-bottom)
render_summary_banner(summary)
st.divider()
render_kpi_cards(df_segments)
st.divider()
st.subheader("Segment Health")
render_segment_table(df_segments)
render_segment_chart(df_segments)
st.divider()
st.subheader("Top At-Risk Customers")
render_at_risk_table(df_at_risk)
```

---

## Integration Points

| External System | Integration Type | Authentication |
|-----------------|-----------------|----------------|
| Snowflake `AD_ANALYTICS.GOLD` | SQL via `run_query()` | SiS: active session; Local: key-pair from `.env` |
| Snowflake `CORTEX.COMPLETE` | SQL function call via `run_query()` | Same session — no additional auth |

No new external integrations. No EAI changes. No new secrets.

---

## Testing Strategy

| Test Type | Scope | Method | Coverage |
|-----------|-------|--------|----------|
| Manual — local dev | Full page | `streamlit run app.py` → navigate to Page 5 | AT-001, AT-002, AT-007 |
| Manual — SiS | Full page | `snow streamlit deploy --replace` → open in Snowsight | AT-006 |
| Manual — LLM failure | Graceful degradation | Temporarily set `LLM_MODEL = "nonexistent-model"` → verify banner fallback | AT-003 |
| Manual — cache | Cache behavior | Load Page 5, reload within 10 min, verify same summary | AT-004 |
| Visual | Dark theme | Verify `#1E1E1E` backgrounds, consistent with Pages 1-4 | AT-001 |

**No automated tests** — consistent with Pages 1-4 which have no automated tests. The page is read-only (no writes, no side effects).

---

## Error Handling

| Error Type | Handling Strategy | Retry? |
|------------|-------------------|--------|
| CORTEX.COMPLETE unavailable | `generate_executive_summary()` returns `None`; banner shows "Executive summary unavailable" | No — next cache miss retries in 10 min |
| CORTEX.COMPLETE returns empty | Same as above — `None` path | No |
| Model not available in region | Change `LLM_MODEL` constant to `"llama3.1-70b"` (one-line fix) | N/A |
| D_CUSTOMER_SEGMENTATION empty | `load_segment_summary()` returns empty DataFrame; KPIs show 0; tables show "No data" via `dark_dataframe()` | No |
| Snowflake connection error | Existing `run_query()` behavior — Streamlit shows error | No |

---

## Configuration

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `LLM_MODEL` | str | `"gemini-2-5-flash"` | Cortex LLM model for executive summary |
| `LLM_CACHE_TTL` | int | `600` | Cache TTL in seconds for LLM call |
| `CONCERNING_SEGMENTS` | set | 6 values | Segments shown in at-risk table and KPI count |
| `POSITIVE_SEGMENTS` | set | 6 values | Segments used for "Healthy %" KPI |

All defined as module-level constants at the top of the page file. No external config file.

---

## Security Considerations

- **No PII exposure in LLM prompt** — only aggregated segment counts and values are sent to CORTEX.COMPLETE, not customer emails or names
- **SQL injection** — prompt uses single-quote escaping (`replace("'", "''")`); segment names in `IN` clause are from hardcoded Python constants, not user input
- **RBAC** — page queries run under the viewer's session role; CORTEX.COMPLETE access must be granted to `DASHBOARD_VIEWER_ROLE` and `POWERBI_READONLY_ROLE` (validation item A-004)
- **No new secrets** — uses existing Snowflake session

---

## Observability

| Aspect | Implementation |
|--------|----------------|
| Logging | None — consistent with Pages 1-4 (no structured logging) |
| Metrics | LLM cost tracked via Snowflake `CORTEX_CONSUMPTION` view (built-in) |
| Errors | LLM failures silently degrade to fallback caption — no alerting needed for MVP |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-15 | design-agent | Initial version |

---

## Next Step

**Ready for:** `/build .claude/sdd/features/DESIGN_CHURN_NARRATIVES.md`
