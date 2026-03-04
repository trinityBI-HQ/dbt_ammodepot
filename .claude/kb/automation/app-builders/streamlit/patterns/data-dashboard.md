# Data Dashboard Pattern

> **Purpose**: Build interactive dashboards with filters, KPIs, charts, and data tables
> **MCP Validated**: 2026-03-03

## When to Use

- Building analytics dashboards with filter-driven views
- Displaying KPI metrics with trend indicators
- Combining charts and tables in a single page
- Prototyping BI dashboards for stakeholder review

## Implementation

```python
import streamlit as st
import pandas as pd
import plotly.express as px

st.set_page_config(page_title="Sales Dashboard", layout="wide")

# --- Data Loading (cached) ---
@st.cache_data(ttl=3600)
def load_sales_data() -> pd.DataFrame:
    # Replace with your data source
    return pd.read_csv("sales.csv", parse_dates=["order_date"])

df = load_sales_data()

# --- Sidebar Filters ---
with st.sidebar:
    st.title("Filters")
    date_range = st.date_input(
        "Date Range",
        value=(df["order_date"].min(), df["order_date"].max()),
        key="date_filter",
    )
    categories = st.multiselect(
        "Categories",
        options=df["category"].unique(),
        default=df["category"].unique(),
        key="cat_filter",
    )
    min_revenue = st.number_input(
        "Min Revenue", value=0, step=100, key="rev_filter"
    )

# --- Apply Filters ---
mask = (
    (df["order_date"] >= pd.Timestamp(date_range[0]))
    & (df["order_date"] <= pd.Timestamp(date_range[1]))
    & (df["category"].isin(categories))
    & (df["revenue"] >= min_revenue)
)
filtered_df = df[mask]

# --- KPI Row ---
st.title("Sales Dashboard")
kpi1, kpi2, kpi3, kpi4 = st.columns(4)
total_rev = filtered_df["revenue"].sum()
total_orders = len(filtered_df)
avg_order = total_rev / total_orders if total_orders > 0 else 0
unique_customers = filtered_df["customer_id"].nunique()

kpi1.metric("Total Revenue", f"${total_rev:,.0f}", "+12%")
kpi2.metric("Total Orders", f"{total_orders:,}")
kpi3.metric("Avg Order Value", f"${avg_order:,.2f}")
kpi4.metric("Unique Customers", f"{unique_customers:,}")

st.divider()

# --- Charts Row ---
chart_col, table_col = st.columns([2, 1])

with chart_col:
    fig = px.line(
        filtered_df.groupby("order_date")["revenue"].sum().reset_index(),
        x="order_date",
        y="revenue",
        title="Revenue Over Time",
    )
    st.plotly_chart(fig, use_container_width=True)

with table_col:
    st.subheader("Top Categories")
    cat_summary = (
        filtered_df.groupby("category")["revenue"]
        .sum()
        .sort_values(ascending=False)
        .reset_index()
    )
    st.dataframe(cat_summary, hide_index=True, use_container_width=True)

# --- Detail Table with Tabs ---
tab1, tab2 = st.tabs(["Raw Data", "Summary Statistics"])
with tab1:
    st.dataframe(filtered_df, use_container_width=True, hide_index=True)
with tab2:
    st.dataframe(filtered_df.describe(), use_container_width=True)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `layout` | `"centered"` | Set to `"wide"` for dashboards |
| `ttl` | `None` | Cache expiry in seconds |
| `hide_index` | `False` | Set `True` for cleaner tables |
| `use_container_width` | `True` (1.43+) | Charts fill container |

## Auto-Refreshing with Fragments

```python
@st.fragment(run_every="30s")
def live_kpis():
    """This fragment auto-refreshes every 30 seconds without full rerun."""
    latest = fetch_latest_metrics()  # uncached, always fresh
    c1, c2 = st.columns(2)
    c1.metric("Active Users", latest["users"])
    c2.metric("Revenue Today", f"${latest['revenue']:,.0f}")

live_kpis()
```

## See Also

- [Caching](../concepts/caching.md)
- [Layouts](../concepts/layouts.md)
- [Database Integration](../patterns/database-integration.md)
