"""Today / Yesterday — Real-time sales dashboard.

Replaces: SALES OVERVIEW FASTER (Power BI — 1,188 views, #1 most used)
Source: AD_ANALYTICS.GOLD.F_SALES
"""

import base64
import pathlib
import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query, _is_sis
from utils.chart_theme import apply_theme, ACCENT, secondary_axis_style, dark_dataframe

_logo_path = pathlib.Path(__file__).parents[1] / "AmmoDepot.png"
_logo_b64 = base64.b64encode(_logo_path.read_bytes()).decode()
if hasattr(st, "logo"):
    st.logo(str(_logo_path))

# --- Page config ---
st.markdown(
    "<style>"
    "   .block-container {padding-left: 1rem; padding-right: 1rem; max-width: 100%;}"
    "   .stMainBlockContainer {max-width: 100%;}"
    "   [data-testid='stDataFrame'] {background: #1E1E1E; border-radius: 8px; padding: 4px;}"
    "   [data-testid='stDataFrame'] [data-testid='glideDataEditor'] {border-radius: 6px;}"
    "</style>",
    unsafe_allow_html=True,
)
st.markdown(
    f'<div style="display:flex;align-items:center;gap:12px;">'
    f'<img src="data:image/png;base64,{_logo_b64}" height="48">'
    f'<h1 style="margin:0;">SALES OVERVIEW: TODAY / YESTERDAY</h1>'
    f'</div>',
    unsafe_allow_html=True,
)

# Statuses preselected by default (matches Power BI default filter)
DEFAULT_STATUSES = {"COMPLETE", "PROCESSING", "UNVERIFIED"}


@st.cache_data(ttl=3600)
def load_order_statuses() -> list:
    df = run_query("select distinct upper(STATUS) as STATUS from F_SALES order by STATUS")
    return df["STATUS"].tolist() if not df.empty else []


all_statuses = load_order_statuses()
default_statuses = [s for s in all_statuses if s in DEFAULT_STATUSES]

# --- Filters ---
filter_cols = st.columns([2, 2, 2, 3, 3])
with filter_cols[0]:
    period = st.radio("Period", ["TODAY", "Yesterday"], horizontal=True)
with filter_cols[1]:
    order_status = st.multiselect(
        "Order Status",
        all_statuses,
        default=default_statuses,
    )
with filter_cols[2]:
    metric_toggle = st.radio("Metric", ["$", "GP ($)", "Orders", "Units"], horizontal=True)
with filter_cols[3]:
    analytical_view = st.radio("Analytical View", ["Hourly", "Bar Chart", "Heat Map"], horizontal=True)

# Metric mapping: toggle value → (column, format, label)
METRIC_MAP = {
    "$": ("NET_SALES", "${:,.0f}", "Sales ($)"),
    "GP ($)": ("GP", "${:,.0f}", "Gross Profit ($)"),
    "Orders": ("ORDERS", "{:,.0f}", "Orders"),
    "Units": ("UNITS", "{:,.0f}", "Units"),
}
metric_col, metric_fmt, metric_label = METRIC_MAP[metric_toggle]

# --- Date logic ---
today = date.today()
if period == "TODAY":
    target_date = today
    compare_date = today - timedelta(days=1)
else:
    target_date = today - timedelta(days=1)
    compare_date = today - timedelta(days=2)


# --- Data loading ---
@st.cache_data(ttl=300)
def load_sales(dt: date, statuses: tuple) -> pd.DataFrame:
    status_list = ", ".join(f"'{s}'" for s in statuses)
    sql = f"""
        select
            f.CREATED_AT,
            f.TIMEDATE,
            extract(HOUR from f.TIMEDATE) as HOUR_NUM,
            f.INCREMENT_ID as ORDER_ID,
            f.CUSTOMER_EMAIL,
            f.CUSTOMER_NAME,
            f.STORE_ID,
            f.STOREFRONT,
            f.STATUS,
            f.ROW_TOTAL as NET_SALES,
            f.COST,
            f.QTY_ORDERED,
            f.FREIGHT_REVENUE,
            f.FREIGHT_COST,
            p."Vendor" as VENDOR,
            p."Attribute Set" as CATEGORY,
            p."Manufacturer" as MANUFACTURER,
            f.PRODUCT_ID,
            f.TESTSKU as SKU,
            p."Manufacturer SKU" as MANUFACTURER_SKU,
            p."Product Name" as PRODUCT_NAME,
            f.PART_QTY_SOLD::int as UNITS,
            f.REGION,
            f.CITY,
            f.POSTCODE
        from F_SALES f
        left join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
        where f.CREATED_AT = '{dt}'
          and f.STATUS in ({status_list})
    """
    return run_query(sql)


@st.cache_data(ttl=300)
def load_sales_range(start_dt: date, end_dt: date, statuses: tuple) -> pd.DataFrame:
    status_list = ", ".join(f"'{s}'" for s in statuses)
    sql = f"""
        select
            CREATED_AT,
            extract(HOUR from TIMEDATE) as HOUR_NUM,
            INCREMENT_ID as ORDER_ID,
            STORE_ID,
            STOREFRONT,
            STATUS,
            ROW_TOTAL as NET_SALES,
            COST,
            coalesce(PART_QTY_SOLD, QTY_ORDERED)::int as UNITS
        from F_SALES
        where CREATED_AT between '{start_dt}' and '{end_dt}'
          and STATUS in ({status_list})
    """
    return run_query(sql)


@st.cache_data(ttl=3600)
def load_last_month_sales(statuses: tuple) -> pd.DataFrame:
    """Load last 30 days of sales for Average LM line."""
    status_list = ", ".join(f"'{s}'" for s in statuses)
    sql = f"""
        select
            CREATED_AT,
            extract(HOUR from TIMEDATE) as HOUR_NUM,
            INCREMENT_ID as ORDER_ID,
            ROW_TOTAL as NET_SALES,
            COST,
            coalesce(PART_QTY_SOLD, QTY_ORDERED)::int as UNITS,
            STORE_ID,
            STOREFRONT
        from F_SALES
        where CREATED_AT between dateadd(day, -30, current_date)
              and dateadd(day, -1, current_date)
          and STATUS in ({status_list})
    """
    return run_query(sql)


@st.cache_data(ttl=3600)
def load_store_names() -> pd.DataFrame:
    return run_query("select STORE_ID, NAME from D_STORE where IS_ACTIVE = true")


store_df = load_store_names()
statuses = tuple(order_status) if order_status else ("complete",)
df_target = load_sales(target_date, statuses)
df_compare = load_sales(compare_date, statuses)
df_last_month = load_last_month_sales(statuses)


# --- Storefront + Store filters (UI rendered at bottom, filtering here) ---
STOREFRONTS = ["Website", "GunBroker"]
for sf in STOREFRONTS:
    if f"ty_sf_{sf}" not in st.session_state:
        st.session_state[f"ty_sf_{sf}"] = True

store_names = store_df["NAME"].tolist() if not store_df.empty else []
for name in store_names:
    if f"ty_store_{name}" not in st.session_state:
        st.session_state[f"ty_store_{name}"] = True

# Apply storefront filter from session state
selected_storefronts = [sf for sf in STOREFRONTS if st.session_state.get(f"ty_sf_{sf}", True)]
if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]
    if not df_last_month.empty:
        df_last_month = df_last_month[
            df_last_month["STOREFRONT"].isin(selected_storefronts)
        ]

# Apply store filter from session state
selected_store_ids = []
for name in store_names:
    if st.session_state.get(f"ty_store_{name}", True):
        sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
        selected_store_ids.append(sid)
if selected_store_ids and not df_target.empty:
    df_target = df_target[df_target["STORE_ID"].isin(selected_store_ids)]
    df_compare = df_compare[df_compare["STORE_ID"].isin(selected_store_ids)]
    if not df_last_month.empty:
        df_last_month = df_last_month[
            df_last_month["STORE_ID"].isin(selected_store_ids)
        ]

# --- Cross-filters (PBI-style click-to-filter) ---
_XF_KEYS = ["ty_xf_cat", "ty_xf_mfr", "ty_xf_vendor", "ty_xf_sku", "ty_xf_cust"]

# Apply any pending chart-click filter BEFORE widgets render
_pending = st.session_state.pop("_ty_xf_pending", None)
if _pending:
    _pkey, _pval = _pending
    st.session_state[_pkey] = _pval

for _k in _XF_KEYS:
    if _k not in st.session_state:
        st.session_state[_k] = "All"


def _clear_ty_xf():
    """Callback to clear all cross-filters (runs before widgets render)."""
    for _k in _XF_KEYS:
        st.session_state[_k] = "All"


if not df_target.empty:
    _df_opts = df_target  # dropdown options from pre-cross-filter data
    xf_cols = st.columns([2, 2, 2, 2, 2, 1])
    with xf_cols[0]:
        xf_cat = st.selectbox(
            "Category",
            ["All"] + sorted(_df_opts["CATEGORY"].dropna().unique().tolist()),
            key="ty_xf_cat",
        )
    with xf_cols[1]:
        xf_mfr = st.selectbox(
            "Manufacturer",
            ["All"] + sorted(_df_opts["MANUFACTURER"].dropna().unique().tolist()),
            key="ty_xf_mfr",
        )
    with xf_cols[2]:
        xf_vendor = st.selectbox(
            "Fulfilled By",
            ["All"] + sorted(_df_opts["VENDOR"].dropna().unique().tolist()),
            key="ty_xf_vendor",
        )
    with xf_cols[3]:
        xf_sku = st.selectbox(
            "SKU",
            ["All"] + sorted(_df_opts["MANUFACTURER_SKU"].dropna().unique().tolist()),
            key="ty_xf_sku",
        )
    with xf_cols[4]:
        xf_cust = st.selectbox(
            "Customer",
            ["All"] + sorted(_df_opts["CUSTOMER_EMAIL"].dropna().unique().tolist()),
            key="ty_xf_cust",
        )
    with xf_cols[5]:
        st.markdown("<br>", unsafe_allow_html=True)
        st.button("Clear All", key="ty_xf_clear", on_click=_clear_ty_xf)

    # Apply cross-filters to target + compare
    _xf_pairs = [
        ("CATEGORY", xf_cat), ("MANUFACTURER", xf_mfr),
        ("VENDOR", xf_vendor), ("MANUFACTURER_SKU", xf_sku),
        ("CUSTOMER_EMAIL", xf_cust),
    ]
    for _col, _val in _xf_pairs:
        if _val != "All":
            df_target = df_target[df_target[_col] == _val]
            if not df_compare.empty:
                df_compare = df_compare[df_compare[_col] == _val]

    # Active filter pills
    _active = [
        (lbl, st.session_state.get(k, "All"))
        for lbl, k in [
            ("Category", "ty_xf_cat"), ("Manufacturer", "ty_xf_mfr"),
            ("Fulfilled By", "ty_xf_vendor"), ("SKU", "ty_xf_sku"),
            ("Customer", "ty_xf_cust"),
        ]
        if st.session_state.get(k, "All") != "All"
    ]
    if _active:
        _pills = " ".join(
            f'<span style="background:#2a3f5f;color:#00d4aa;padding:2px 10px;'
            f'border-radius:12px;font-size:12px;margin-right:4px;">'
            f'{lbl}: {val}</span>'
            for lbl, val in _active
        )
        st.markdown(
            f'<div style="margin:4px 0 8px 0;">'
            f'<span style="color:#888;font-size:12px;">Active filters: </span>'
            f'{_pills}</div>',
            unsafe_allow_html=True,
        )

# --- Compute GP for downstream use ---
if not df_target.empty:
    df_target = df_target.copy()
    df_target["GP"] = df_target["NET_SALES"] - df_target["COST"]
if not df_compare.empty:
    df_compare = df_compare.copy()
    df_compare["GP"] = df_compare["NET_SALES"] - df_compare["COST"]

# --- KPI calculations ---
net_sales = df_target["NET_SALES"].sum() if not df_target.empty else 0
cost = df_target["COST"].sum() if not df_target.empty else 0
gross_profit = net_sales - cost
orders = df_target["ORDER_ID"].nunique() if not df_target.empty else 0
units = df_target["UNITS"].sum() if not df_target.empty else 0
freight_rev = df_target["FREIGHT_REVENUE"].sum() if not df_target.empty else 0
freight_cost = df_target["FREIGHT_COST"].sum() if not df_target.empty else 0
gp_after_var = gross_profit - freight_cost

net_sales_prev = df_compare["NET_SALES"].sum() if not df_compare.empty else 0
cost_prev = df_compare["COST"].sum() if not df_compare.empty else 0
gp_prev = net_sales_prev - cost_prev
orders_prev = df_compare["ORDER_ID"].nunique() if not df_compare.empty else 0
freight_rev_prev = df_compare["FREIGHT_REVENUE"].sum() if not df_compare.empty else 0
gp_after_var_prev = gp_prev - (df_compare["FREIGHT_COST"].sum() if not df_compare.empty else 0)

margin = (gross_profit / net_sales * 100) if net_sales else 0
avg_ticket = (net_sales / orders) if orders else 0
orders_per_day = orders


def pct_delta(current, previous):
    if previous and previous != 0:
        return f"{((current - previous) / abs(previous)) * 100:+.1f}%"
    return None


# --- KPI Row ---
st.divider()

shipping_ns_pct = (freight_rev / net_sales * 100) if net_sales else 0
contrib_margin = (gp_after_var / net_sales * 100) if net_sales else 0
compare_label = "Yesterday" if period == "TODAY" else "Previous"

kpi_cards = [
    {
        "icon": "&#x1F4B2;",
        "color": "#00B4D8",
        "title": "Net Sales",
        "value": f"${net_sales:,.0f}",
        "delta": pct_delta(net_sales, net_sales_prev),
        "sub_label": "Avg Ticket",
        "sub_value": f"${avg_ticket:,.2f}",
    },
    {
        "icon": "&#x1F4C8;",
        "color": "#2DC653",
        "title": "Gross Profit",
        "value": f"${gross_profit:,.0f}",
        "delta": pct_delta(gross_profit, gp_prev),
        "sub_label": "Margin",
        "sub_value": f"{margin:.1f}%",
    },
    {
        "icon": "&#x1F6D2;",
        "color": "#00B4D8",
        "title": "Orders",
        "value": f"{orders:,}",
        "delta": pct_delta(orders, orders_prev),
        "sub_label": "Orders/Day",
        "sub_value": f"{orders_per_day}",
    },
    {
        "icon": "&#x1F69A;",
        "color": "#2DC653",
        "title": "Shipping Revenue",
        "value": f"${freight_rev:,.0f}",
        "delta": pct_delta(freight_rev, freight_rev_prev),
        "sub_label": "Shipping/NS",
        "sub_value": f"{shipping_ns_pct:.1f}%",
    },
    {
        "icon": "&#x1F6E1;",
        "color": "#00B4D8",
        "title": "GP After Var Cost",
        "value": f"${gp_after_var:,.0f}",
        "delta": pct_delta(gp_after_var, gp_after_var_prev),
        "sub_label": "Contribution Margin",
        "sub_value": f"{contrib_margin:.1f}%",
    },
]

st.markdown(
    """
    <style>
    .kpi-card {
        background: #1E1E1E;
        border-radius: 8px;
        padding: 12px 16px;
        border-left: 4px solid;
        height: 100%;
    }
    .kpi-header {
        display: flex;
        align-items: center;
        gap: 6px;
        margin-bottom: 4px;
    }
    .kpi-icon { font-size: 18px; }
    .kpi-title {
        font-size: 12px;
        color: #AAAAAA;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }
    .kpi-value {
        font-size: 24px;
        font-weight: 700;
        color: #FFFFFF;
        margin: 2px 0;
    }
    .kpi-delta {
        font-size: 12px;
        margin-bottom: 6px;
    }
    .kpi-delta-pos { color: #2DC653; }
    .kpi-delta-neg { color: #FF4B4B; }
    .kpi-delta-zero { color: #AAAAAA; }
    .kpi-sub {
        font-size: 11px;
        color: #888888;
        border-top: 1px solid #333;
        padding-top: 6px;
        margin-top: 4px;
    }
    .kpi-sub-val {
        color: #CCCCCC;
        font-weight: 600;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

kpi_cols = st.columns(5)
for i, card in enumerate(kpi_cards):
    delta = card["delta"]
    if delta and delta.startswith("+"):
        delta_class = "kpi-delta-pos"
    elif delta and delta.startswith("-"):
        delta_class = "kpi-delta-neg"
    else:
        delta_class = "kpi-delta-zero"
    delta_text = f"vs {compare_label}: {delta}" if delta else f"vs {compare_label}: --"

    html = f"""
    <div class="kpi-card" style="border-left-color: {card['color']};">
        <div class="kpi-header">
            <span class="kpi-icon">{card['icon']}</span>
            <span class="kpi-title">{card['title']}</span>
        </div>
        <div class="kpi-value">{card['value']}</div>
        <div class="kpi-delta {delta_class}">{delta_text}</div>
        <div class="kpi-sub">
            {card['sub_label']}: <span class="kpi-sub-val">{card['sub_value']}</span>
        </div>
    </div>
    """
    with kpi_cols[i]:
        st.markdown(html, unsafe_allow_html=True)

st.divider()

# --- Helpers for Analytical View charts ---


def _hour_label(h):
    """Format hour integer as '12:00 AM', '1:00 AM', etc."""
    if h == 0:
        return "12:00 AM"
    elif h < 12:
        return f"{h}:00 AM"
    elif h == 12:
        return "12:00 PM"
    else:
        return f"{h - 12}:00 PM"


def _hourly_agg(df, metric):
    """Aggregate a single day's data by hour for the selected metric."""
    if df.empty:
        return pd.DataFrame(columns=["HOUR", "HOUR_LABEL", "VALUE"])
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    if metric == "Orders":
        r = df.groupby("HOUR_NUM")["ORDER_ID"].nunique()
    elif metric == "Units":
        r = df.groupby("HOUR_NUM")["UNITS"].sum()
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        r = df.groupby("HOUR_NUM")[col].sum()
    result = r.reset_index().set_axis(["HOUR", "VALUE"], axis=1)
    result["HOUR_LABEL"] = result["HOUR"].apply(_hour_label)
    return result


def _hourly_avg(df, metric):
    """Compute average hourly values across multiple days (for LM line)."""
    if df.empty:
        return pd.DataFrame(columns=["HOUR", "HOUR_LABEL", "VALUE"])
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    df["HOUR"] = df["HOUR_NUM"]
    df["DAY"] = df["CREATED_AT"]
    n_days = df["DAY"].nunique()
    if n_days == 0:
        return pd.DataFrame(columns=["HOUR", "HOUR_LABEL", "VALUE"])
    if metric == "Orders":
        daily = df.groupby(["DAY", "HOUR"])["ORDER_ID"].nunique().reset_index(
            name="VAL"
        )
    elif metric == "Units":
        daily = df.groupby(["DAY", "HOUR"])["UNITS"].sum().reset_index(name="VAL")
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        daily = df.groupby(["DAY", "HOUR"])[col].sum().reset_index(name="VAL")
    avg = daily.groupby("HOUR")["VAL"].mean().reset_index()
    avg.columns = ["HOUR", "VALUE"]
    avg["HOUR_LABEL"] = avg["HOUR"].apply(_hour_label)
    return avg


# --- Charts row ---
chart_cols = st.columns([40, 20, 20, 20])

# Analytical View chart (first column — switches between Hourly / Bar Chart / Heat Map)
with chart_cols[0]:
    if analytical_view == "Hourly":
        st.subheader(f"{metric_label} / Hourly")
        if not df_target.empty:
            hourly_target = _hourly_agg(df_target, metric_toggle)
            fig = go.Figure()
            target_vals = hourly_target["VALUE"].tolist()
            target_text = [f"{int(round(v))}" for v in target_vals]
            fig.add_trace(go.Scatter(
                x=hourly_target["HOUR_LABEL"].tolist(),
                y=target_vals,
                name=period, marker_color="#00d4aa",
                mode="lines+markers+text",
                marker=dict(size=6),
                text=target_text, textposition="top center",
                textfont=dict(size=10, color="#00d4aa"),
            ))
            if not df_compare.empty:
                hourly_compare = _hourly_agg(df_compare, metric_toggle)
                fig.add_trace(go.Scatter(
                    x=hourly_compare["HOUR_LABEL"].tolist(),
                    y=hourly_compare["VALUE"].tolist(),
                    name="YESTERDAY",
                    line=dict(color="gray", dash="dash"),
                ))
            # Average LM (last 30 days average)
            lm_avg = None
            if not df_last_month.empty:
                hourly_lm = _hourly_avg(df_last_month, metric_toggle)
                if not hourly_lm.empty:
                    lm_avg = float(hourly_lm["VALUE"].mean())
                    fig.add_trace(go.Scatter(
                        x=hourly_lm["HOUR_LABEL"].tolist(),
                        y=hourly_lm["VALUE"].tolist(),
                        name="Average LM",
                        line=dict(color="gray", dash="dot", width=1),
                        mode="lines",
                    ))
            # Average line for target day
            target_avg = float(hourly_target["VALUE"].mean())
            fig.add_hline(
                y=target_avg, line_dash="dot", line_color="#00d4aa",
                line_width=1,
            )
            # Summary below chart header
            avg_text = f"Average  **{target_avg:,.0f}**"
            if lm_avg is not None:
                avg_text += f"  &nbsp;·&nbsp;  Average LM  **{lm_avg:,.2f}**"
            apply_theme(fig)
            fig.update_xaxes(
                categoryorder="array",
                categoryarray=[_hour_label(h) for h in range(24)],
                title="Hour",
            )
            fig.update_yaxes(title="")
            st.caption(avg_text)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data for this period.")

    elif analytical_view == "Bar Chart":
        st.subheader(f"{metric_label} / Daily Trend")
        trend_start = today - timedelta(days=6)
        df_trend = load_sales_range(trend_start, today, statuses)
        # Apply same filters as main data
        if selected_storefronts and not df_trend.empty:
            df_trend = df_trend[df_trend["STOREFRONT"].isin(selected_storefronts)]
        if selected_store_ids and not df_trend.empty:
            df_trend = df_trend[df_trend["STORE_ID"].isin(selected_store_ids)]
        if not df_trend.empty:
            df_trend = df_trend.copy()
            df_trend["GP"] = df_trend["NET_SALES"] - df_trend["COST"]
            daily = df_trend.groupby(df_trend["CREATED_AT"]).agg(
                NET_SALES=("NET_SALES", "sum"),
                COST=("COST", "sum"),
                GP=("GP", "sum"),
                ORDERS=("ORDER_ID", pd.Series.nunique),
                UNITS=("UNITS", "sum"),
            ).reset_index()
            daily.columns = ["DAY", "NET_SALES", "COST", "GP", "ORDERS", "UNITS"]
            daily["MARGIN"] = (daily["GP"] / daily["NET_SALES"] * 100).fillna(0)
            val_col = {"$": "NET_SALES", "GP ($)": "GP", "Orders": "ORDERS", "Units": "UNITS"}[metric_toggle]
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=daily["DAY"].tolist(), y=daily[val_col].tolist(),
                name=metric_label, marker_color="#00d4aa",
            ))
            fig.add_trace(go.Scatter(
                x=daily["DAY"].tolist(), y=daily["MARGIN"].tolist(), name="Margin %", yaxis="y2",
                mode="lines+markers+text",
                text=[f"{m:.0f}%" for m in daily["MARGIN"].tolist()],
                textposition="top center", line=dict(color="#4CAF50"),
            ))
            apply_theme(fig, margin=dict(l=0, r=40, t=10, b=0))
            fig.update_layout(
                yaxis2=dict(
                    title="Margin %", overlaying="y", side="right",
                    range=[0, 100], **secondary_axis_style(),
                ),
            )
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

    else:  # Heat Map
        st.subheader(f"{metric_label} / Heat Map - {period}")
        trend_start = today - timedelta(days=6)
        df_heat = load_sales_range(trend_start, today, statuses)
        if selected_storefronts and not df_heat.empty:
            df_heat = df_heat[df_heat["STOREFRONT"].isin(selected_storefronts)]
        if selected_store_ids and not df_heat.empty:
            df_heat = df_heat[df_heat["STORE_ID"].isin(selected_store_ids)]
        if not df_heat.empty:
            df_heat = df_heat.copy()
            df_heat["GP"] = df_heat["NET_SALES"] - df_heat["COST"]
            df_heat["HOUR"] = df_heat["HOUR_NUM"]
            df_heat["DOW_NUM"] = pd.to_datetime(df_heat["CREATED_AT"]).dt.dayofweek
            df_heat["DOW"] = pd.to_datetime(df_heat["CREATED_AT"]).dt.day_name()
            if metric_toggle == "Orders":
                hm = df_heat.groupby(["DOW_NUM", "DOW", "HOUR"])["ORDER_ID"].nunique().reset_index(name="VALUE")
            elif metric_toggle == "Units":
                hm = df_heat.groupby(["DOW_NUM", "DOW", "HOUR"])["UNITS"].sum().reset_index(name="VALUE")
            else:
                col = "GP" if metric_toggle == "GP ($)" else "NET_SALES"
                hm = df_heat.groupby(["DOW_NUM", "DOW", "HOUR"])[col].sum().reset_index(name="VALUE")
            pivot = hm.pivot_table(index=["DOW_NUM", "DOW"], columns="HOUR", values="VALUE", fill_value=0)
            pivot = pivot.sort_index(level=0)
            dow_labels = [row[1] for row in pivot.index]
            fig = go.Figure(data=go.Heatmap(
                z=pivot.values.tolist(),
                x=[_hour_label(h) for h in pivot.columns],
                y=dow_labels,
                colorscale="Greens",
                hoverongaps=False,
            ))
            apply_theme(fig, show_legend=False, margin=dict(l=0, r=0, t=10, b=0))
            fig.update_xaxes(title="Hour", dtick=2)
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

# Helper: aggregate by dimension using selected metric


def agg_by_metric(df, group_col, metric):
    if df.empty:
        return pd.DataFrame()
    df = df.copy()
    df[group_col] = df[group_col].fillna("(Blank)")
    df["GP"] = df["NET_SALES"] - df["COST"]
    if metric == "Orders":
        result = df.groupby(group_col)["ORDER_ID"].nunique().reset_index()
        result.columns = [group_col, "VALUE"]
    elif metric == "Units":
        result = df.groupby(group_col)["UNITS"].sum().reset_index()
        result.columns = [group_col, "VALUE"]
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        result = df.groupby(group_col)[col].sum().reset_index()
        result.columns = [group_col, "VALUE"]
    return result.sort_values("VALUE", ascending=False).head(8)


def _build_cmp_map(df_cmp, group_col, metric):
    """Build comparison lookup dict for a dimension."""
    if df_cmp is None or df_cmp.empty:
        return {}
    cmp_agg = agg_by_metric(df_cmp, group_col, metric)
    if cmp_agg.empty:
        return {}
    return dict(zip(cmp_agg[group_col].tolist(), cmp_agg["VALUE"].tolist()))


def _render_clickable_hbar(labels, values, metric, limit=15, compare_map=None,
                           filter_key=None, chart_key=None):
    """Render clickable Plotly horizontal bars. Click a bar to cross-filter."""
    if not labels or not values:
        st.info("No data.")
        return
    labels = labels[:limit]
    values = values[:limit]
    total = sum(values)
    is_money = metric in ("$", "GP ($)", "GP ($) After VC")
    if compare_map is None:
        compare_map = {}

    # Active filter highlighting
    active_val = (
        st.session_state.get(filter_key, "All") if filter_key else "All"
    )

    # Reverse for bottom-up (highest at top)
    labels_r = labels[::-1]
    values_r = [float(v) for v in values[::-1]]

    # Pre-compute % change per label for bar color assignment
    chg_map = {}
    for lbl, val in zip(labels_r, values_r):
        if compare_map:
            cmp_val = compare_map.get(lbl, 0)
            chg_map[lbl] = (val - cmp_val) / cmp_val * 100 if cmp_val > 0 else None
        else:
            chg_map[lbl] = None

    n = len(labels_r)
    colors = []
    for i, lbl in enumerate(labels_r):
        chg = chg_map.get(lbl)
        is_top = (i == n - 1)
        if active_val != "All":
            if lbl == active_val:
                colors.append("#00c853" if (chg is not None and chg >= 0) else "#f44336" if chg is not None else "#00d4aa")
            else:
                colors.append("rgba(128,128,128,0.15)")
        else:
            if chg is None:
                colors.append("#00d4aa" if is_top else "rgba(0,212,170,0.60)")
            elif chg >= 0:
                colors.append("#00c853" if is_top else "rgba(0,200,83,0.60)")
            else:
                colors.append("#f44336" if is_top else "rgba(244,67,54,0.60)")

    text_items = []
    for lbl, val in zip(labels_r, values_r):
        pct = (val / total * 100) if total else 0
        val_str = f"${val:,.0f}" if is_money else f"{int(val):,}"
        lbl_display = lbl[:20] + "…" if len(lbl) > 20 else lbl
        chg_str = ""
        if compare_map:
            cmp_val = compare_map.get(lbl, 0)
            if cmp_val > 0:
                chg = (val - cmp_val) / cmp_val * 100
                arrow = "\u25b2" if chg >= 0 else "\u25bc"
                chg_str = f"  {arrow}{abs(chg):.0f}%"
            else:
                chg_str = "  \u25cf New"
        text_items.append(f"{lbl_display}  {val_str} ({pct:.0f}%){chg_str}")

    fig = go.Figure(go.Bar(
        y=list(range(len(labels_r))),
        x=values_r,
        orientation="h",
        marker_color=colors,
        text=text_items,
        textposition="auto",
        insidetextanchor="start",
        textfont=dict(size=10, color="#eee"),
        outsidetextfont=dict(size=10, color="#ccc"),
        cliponaxis=False,
        hoverinfo="skip",
    ))
    apply_theme(
        fig,
        height=max(len(labels_r) * 32, 100),
        show_legend=False,
        margin=dict(l=0, r=0, t=0, b=0),
    )
    fig.update_layout(
        yaxis=dict(showticklabels=False, showgrid=False, zeroline=False),
        xaxis=dict(showticklabels=False, showgrid=False, zeroline=False),
        bargap=0.25,
    )

    if chart_key and filter_key and not _is_sis:
        event = st.plotly_chart(
            fig, use_container_width=True,
            on_select="rerun", key=chart_key,
        )
        try:
            sel = event.selection if event else None
            if sel and not callable(sel) and hasattr(sel, "points") and sel.points:
                idx = sel.points[0]["point_index"]
                clicked = labels_r[idx]
                current = st.session_state.get(filter_key, "All")
                new_val = "All" if current == clicked else clicked
                st.session_state["_ty_xf_pending"] = (filter_key, new_val)
                st.rerun()
        except (AttributeError, TypeError, IndexError):
            pass  # Older Streamlit — chart click not supported
    else:
        st.plotly_chart(fig, use_container_width=True)


# Category chart (clickable → sets Category cross-filter)
with chart_cols[1]:
    st.subheader(f"{metric_label} / Category")
    if not df_target.empty:
        cat_agg = agg_by_metric(df_target, "CATEGORY", metric_toggle).head(15)
        if not cat_agg.empty:
            _render_clickable_hbar(
                cat_agg["CATEGORY"].tolist(),
                cat_agg["VALUE"].tolist(),
                metric_toggle,
                compare_map=_build_cmp_map(df_compare, "CATEGORY", metric_toggle),
                filter_key="ty_xf_cat", chart_key="ty_cat_chart",
            )
    else:
        st.info("No data.")

# Fulfilled By chart (clickable → sets Fulfilled By cross-filter)
with chart_cols[2]:
    st.subheader(f"{metric_label} / Fulfilled By")
    if not df_target.empty:
        vendor_agg = agg_by_metric(df_target, "VENDOR", metric_toggle).head(15)
        if not vendor_agg.empty:
            _render_clickable_hbar(
                vendor_agg["VENDOR"].tolist(),
                vendor_agg["VALUE"].tolist(),
                metric_toggle,
                compare_map=_build_cmp_map(df_compare, "VENDOR", metric_toggle),
                filter_key="ty_xf_vendor", chart_key="ty_vendor_chart",
            )
    else:
        st.info("No data.")

# Manufacturer chart (clickable → sets Manufacturer cross-filter)
with chart_cols[3]:
    st.subheader(f"{metric_label} / Manufacturer")
    if not df_target.empty:
        mfr_agg = agg_by_metric(df_target, "MANUFACTURER", metric_toggle).head(15)
        if not mfr_agg.empty:
            _render_clickable_hbar(
                mfr_agg["MANUFACTURER"].tolist(),
                mfr_agg["VALUE"].tolist(),
                metric_toggle,
                compare_map=_build_cmp_map(df_compare, "MANUFACTURER", metric_toggle),
                filter_key="ty_xf_mfr", chart_key="ty_mfr_chart",
            )
    else:
        st.info("No data.")

st.divider()

# --- Product Performance: PBI-style expandable table ---


def _render_product_perf(df, df_cmp, title):
    """Render expandable Manufacturer SKU table with product name detail rows."""
    st.subheader(title)
    if df.empty:
        st.info("No data.")
        return
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    df["MANUFACTURER_SKU"] = df["MANUFACTURER_SKU"].fillna("(No SKU)")
    df["PRODUCT_NAME"] = df["PRODUCT_NAME"].fillna("(No Name)")

    has_freight = "FREIGHT_REVENUE" in df.columns
    sku = df.groupby("MANUFACTURER_SKU").agg(
        **{"NET_SALES": ("NET_SALES", "sum"), "COST": ("COST", "sum"),
           "ORDERS": ("ORDER_ID", "nunique"), "UNITS": ("UNITS", "sum"),
           **({"S_REV": ("FREIGHT_REVENUE", "sum")} if has_freight else {})},
    ).reset_index()
    sku["GP"] = sku["NET_SALES"] - sku["COST"]
    sku["MARGIN"] = (sku["GP"] / sku["NET_SALES"] * 100).fillna(0)
    sku["PU"] = (sku["NET_SALES"] / sku["UNITS"]).fillna(0)
    sku = sku.sort_values("NET_SALES", ascending=False).head(25)
    top = set(sku["MANUFACTURER_SKU"])

    det = df[df["MANUFACTURER_SKU"].isin(top)].groupby(
        ["MANUFACTURER_SKU", "PRODUCT_NAME"]
    ).agg(
        **{"NET_SALES": ("NET_SALES", "sum"), "COST": ("COST", "sum"),
           "ORDERS": ("ORDER_ID", "nunique"), "UNITS": ("UNITS", "sum"),
           **({"S_REV": ("FREIGHT_REVENUE", "sum")} if has_freight else {})},
    ).reset_index()
    det["GP"] = det["NET_SALES"] - det["COST"]
    det["MARGIN"] = (det["GP"] / det["NET_SALES"] * 100).fillna(0)
    det["PU"] = (det["NET_SALES"] / det["UNITS"]).fillna(0)

    cmp_s, cmp_d = {}, {}
    if df_cmp is not None and not df_cmp.empty:
        dc = df_cmp.copy()
        dc["GP"] = dc["NET_SALES"] - dc["COST"]
        dc["MANUFACTURER_SKU"] = dc["MANUFACTURER_SKU"].fillna("(No SKU)")
        dc["PRODUCT_NAME"] = dc["PRODUCT_NAME"].fillna("(No Name)")
        cmp_has_freight = "FREIGHT_REVENUE" in dc.columns
        cs = dc.groupby("MANUFACTURER_SKU").agg(
            **{"NET_SALES": ("NET_SALES", "sum"), "COST": ("COST", "sum"),
               "ORDERS": ("ORDER_ID", "nunique"), "UNITS": ("UNITS", "sum"),
               **({"S_REV": ("FREIGHT_REVENUE", "sum")} if cmp_has_freight else {})},
        ).reset_index()
        cs["GP"] = cs["NET_SALES"] - cs["COST"]
        cmp_s = {r["MANUFACTURER_SKU"]: r for _, r in cs.iterrows()}
        cd = dc.groupby(["MANUFACTURER_SKU", "PRODUCT_NAME"]).agg(
            **{"NET_SALES": ("NET_SALES", "sum"), "COST": ("COST", "sum"),
               "ORDERS": ("ORDER_ID", "nunique"), "UNITS": ("UNITS", "sum"),
               **({"S_REV": ("FREIGHT_REVENUE", "sum")} if cmp_has_freight else {})},
        ).reset_index()
        cd["GP"] = cd["NET_SALES"] - cd["COST"]
        cmp_d = {
            (r["MANUFACTURER_SKU"], r["PRODUCT_NAME"]): r
            for _, r in cd.iterrows()
        }

    def _arrow(cur, prev):
        if prev is None or prev == 0:
            return ""
        if cur > prev:
            return '<span style="color:#4CAF50;">&#9650;</span>'
        if cur < prev:
            return '<span style="color:#f44336;">&#9660;</span>'
        return ""

    def _cells(r, cr=None):
        def g(k):
            return cr[k] if cr is not None else None
        return (
            f'<div class="pp-c">'
            f'{_arrow(r["NET_SALES"], g("NET_SALES"))} '
            f'${r["NET_SALES"]:,.0f}</div>'
            f'<div class="pp-c">'
            f'{_arrow(r["GP"], g("GP"))} '
            f'${r["GP"]:,.0f}</div>'
            f'<div class="pp-c">'
            f'{_arrow(r["ORDERS"], g("ORDERS"))} '
            f'{int(r["ORDERS"]):,}</div>'
            f'<div class="pp-c">'
            f'{_arrow(r["UNITS"], g("UNITS"))} '
            f'{int(r["UNITS"]):,}</div>'
            f'<div class="pp-c">{r["MARGIN"]:.2f}%</div>'
            f'<div class="pp-c">${r["PU"]:,.0f}</div>'
            + (
                f'<div class="pp-c">'
                f'{_arrow(r["S_REV"], g("S_REV"))} '
                f'${r["S_REV"]:,.2f}</div>'
                if has_freight and "S_REV" in r.index else ""
            )
        )

    rows = []
    for _, r in sku.iterrows():
        sk = r["MANUFACTURER_SKU"]
        cells = _cells(r, cmp_s.get(sk))
        sk_det = det[det["MANUFACTURER_SKU"] == sk].sort_values(
            "NET_SALES", ascending=False,
        )
        if len(sk_det) <= 1:
            rows.append(
                f'<div class="pp-row pp-sku">'
                f'<div class="pp-n">{sk}</div>{cells}</div>'
            )
        else:
            dh = ""
            for _, dr in sk_det.iterrows():
                dc = _cells(dr, cmp_d.get((sk, dr["PRODUCT_NAME"])))
                dh += (
                    f'<div class="pp-row pp-det">'
                    f'<div class="pp-n pp-ind">'
                    f'{dr["PRODUCT_NAME"]}</div>{dc}</div>'
                )
            rows.append(
                f'<details class="pp-grp"><summary>'
                f'<div class="pp-row pp-sku">'
                f'<div class="pp-n">'
                f'<span class="pp-x">&#9654;</span> {sk}'
                f'</div>{cells}</div>'
                f'</summary>{dh}</details>'
            )

    t_ns = sku["NET_SALES"].sum()
    t_gp = sku["GP"].sum()
    t_or = int(sku["ORDERS"].sum())
    t_un = int(sku["UNITS"].sum())
    t_mg = (t_gp / t_ns * 100) if t_ns else 0
    t_pu = (t_ns / t_un) if t_un else 0
    t_sr = float(sku["S_REV"].sum()) if has_freight else 0

    grid_cols = (
        "1fr 110px 90px 70px 70px 75px 85px 95px"
        if has_freight
        else "1fr 110px 90px 70px 70px 75px 85px"
    )
    sr_hdr = (
        '<div class="pp-c">S. Revenue ($)</div>' if has_freight else ""
    )
    sr_tot = (
        f'<div class="pp-c">${t_sr:,.2f}</div>' if has_freight else ""
    )

    st.markdown(
        '<style>'
        '.pp-tbl{font-size:13px;width:100%;}'
        '.pp-row{display:grid;'
        f'grid-template-columns:{grid_cols};'
        'gap:4px;padding:6px 10px;border-bottom:1px solid #333;'
        'align-items:center;}'
        '.pp-hdr{background:#2a3f5f;color:#fff;font-weight:700;'
        'border-radius:4px 4px 0 0;}'
        '.pp-sku{background:#1E1E1E;}'
        '.pp-det{background:#161616;}'
        '.pp-tot{background:#2a3f5f;color:#fff;font-weight:700;'
        'border-radius:0 0 4px 4px;border:none;}'
        '.pp-n{color:#fff;font-weight:700;white-space:nowrap;'
        'overflow:hidden;text-overflow:ellipsis;}'
        '.pp-ind{padding-left:20px;color:#aaa;'
        'font-weight:400;font-size:12px;}'
        '.pp-c{text-align:right;color:#ccc;}'
        '.pp-grp>summary{list-style:none;cursor:pointer;}'
        '.pp-grp>summary::-webkit-details-marker{display:none;}'
        '.pp-grp>summary .pp-sku:hover{background:#2a2a2a;}'
        '.pp-x{font-size:9px;color:#888;display:inline-block;'
        'transition:transform 0.15s;}'
        '.pp-grp[open] .pp-x{transform:rotate(90deg);}'
        '</style>'
        '<div class="pp-tbl">'
        '<div class="pp-row pp-hdr">'
        '<div>Manufacturer SKU</div>'
        '<div class="pp-c">Net Sales ($)</div>'
        '<div class="pp-c">GP ($)</div>'
        '<div class="pp-c">Orders</div>'
        '<div class="pp-c">Units</div>'
        '<div class="pp-c">Margin</div>'
        '<div class="pp-c">Price/Unit</div>'
        + sr_hdr
        + '</div>'
        + "".join(rows)
        + f'<div class="pp-row pp-tot"><div>Total</div>'
        f'<div class="pp-c">${t_ns:,.0f}</div>'
        f'<div class="pp-c">${t_gp:,.0f}</div>'
        f'<div class="pp-c">{t_or:,}</div>'
        f'<div class="pp-c">{t_un:,}</div>'
        f'<div class="pp-c">{t_mg:.2f}%</div>'
        f'<div class="pp-c">${t_pu:,.0f}</div>'
        + sr_tot
        + '</div></div>',
        unsafe_allow_html=True,
    )


_render_product_perf(df_target, df_compare, f"Product Performance / {period}")

# --- Geographic / Customer Overview ---
st.divider()
geo_left, geo_right = st.columns([3, 4])

with geo_left:
    geo_view = st.radio("", ["Geographic", "Customer"], horizontal=True, key="geo_view")

    if not df_target.empty:
        # State / City / Zip filters
        filter_geo = st.columns(3)
        states = sorted(df_target["REGION"].dropna().unique().tolist())
        with filter_geo[0]:
            sel_state = st.selectbox("STATE", ["All"] + states, key="geo_state")
        geo_df = df_target if sel_state == "All" else df_target[df_target["REGION"] == sel_state]

        cities = sorted(geo_df["CITY"].dropna().unique().tolist())
        with filter_geo[1]:
            sel_city = st.selectbox("CITY", ["All"] + cities, key="geo_city")
        if sel_city != "All":
            geo_df = geo_df[geo_df["CITY"] == sel_city]

        zips = sorted(geo_df["POSTCODE"].dropna().unique().tolist())
        with filter_geo[2]:
            sel_zip = st.selectbox("ZIP CODE", ["All"] + zips, key="geo_zip")
        if sel_zip != "All":
            geo_df = geo_df[geo_df["POSTCODE"] == sel_zip]

        if geo_view == "Geographic":
            st.caption(f"Geographic Overview / {period}")
            geo_agg = (
                geo_df.groupby("CITY")
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"))
                .reset_index()
            )
            geo_agg["GP"] = geo_agg["NET_SALES"] - geo_agg["COST"]
            geo_agg["MARGIN"] = (geo_agg["GP"] / geo_agg["NET_SALES"] * 100).fillna(0).round(2)
            geo_agg = geo_agg.sort_values("NET_SALES", ascending=False)

            # Add totals row
            totals = pd.DataFrame([{
                "CITY": "Total",
                "NET_SALES": geo_agg["NET_SALES"].sum(),
                "GP": geo_agg["GP"].sum(),
                "ORDERS": geo_agg["ORDERS"].sum(),
                "UNITS": geo_agg["UNITS"].sum(),
                "MARGIN": (geo_agg["GP"].sum() / geo_agg["NET_SALES"].sum() * 100) if geo_agg["NET_SALES"].sum() else 0,
            }])
            geo_display = pd.concat([geo_agg, totals], ignore_index=True)
            cols = ["CITY", "NET_SALES", "GP", "ORDERS", "UNITS", "MARGIN"]
            dark_dataframe(
                geo_display[cols],
                fmt={"NET_SALES": "${:,.0f}", "GP": "${:,.0f}", "MARGIN": "{:.2f}%"},
                height=250,
            )
        else:  # Customer
            st.caption(f"Customer Overview / {period}")
            # Email-level aggregation
            cust_agg = (
                geo_df.groupby(["CUSTOMER_EMAIL", "CUSTOMER_NAME"])
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"))
                .reset_index()
            )
            cust_agg["GP"] = cust_agg["NET_SALES"] - cust_agg["COST"]
            cust_agg = cust_agg.sort_values(
                "NET_SALES", ascending=False,
            ).head(25)
            # Order-level detail
            top_emails = set(cust_agg["CUSTOMER_EMAIL"])
            cust_det = (
                geo_df[geo_df["CUSTOMER_EMAIL"].isin(top_emails)]
                .groupby(["CUSTOMER_EMAIL", "ORDER_ID"])
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     UNITS=("UNITS", "sum"))
                .reset_index()
            )
            cust_det["GP"] = cust_det["NET_SALES"] - cust_det["COST"]
            # Totals
            t_ns = cust_agg["NET_SALES"].sum()
            t_gp = cust_agg["GP"].sum()
            t_or = int(cust_agg["ORDERS"].sum())
            t_un = int(cust_agg["UNITS"].sum())
            # Build HTML rows
            co_rows = []
            for _, r in cust_agg.iterrows():
                email = r["CUSTOMER_EMAIL"]
                name = r["CUSTOMER_NAME"]
                cells = (
                    f'<div class="co-c">{name}</div>'
                    f'<div class="co-c">${r["NET_SALES"]:,.0f}</div>'
                    f'<div class="co-c">${r["GP"]:,.0f}</div>'
                    f'<div class="co-c">{int(r["ORDERS"]):,}</div>'
                    f'<div class="co-c">{int(r["UNITS"]):,}</div>'
                )
                orders = cust_det[
                    cust_det["CUSTOMER_EMAIL"] == email
                ].sort_values("NET_SALES", ascending=False)
                if len(orders) <= 1:
                    co_rows.append(
                        f'<div class="co-row co-cust">'
                        f'<div class="co-n">{email}</div>'
                        f'{cells}</div>'
                    )
                else:
                    dh = ""
                    for _, dr in orders.iterrows():
                        dh += (
                            f'<div class="co-row co-det">'
                            f'<div class="co-n co-ind">'
                            f'{dr["ORDER_ID"]}</div>'
                            f'<div class="co-c"></div>'
                            f'<div class="co-c">'
                            f'${dr["NET_SALES"]:,.0f}</div>'
                            f'<div class="co-c">'
                            f'${dr["GP"]:,.0f}</div>'
                            f'<div class="co-c">1</div>'
                            f'<div class="co-c">'
                            f'{int(dr["UNITS"]):,}</div>'
                            f'</div>'
                        )
                    co_rows.append(
                        f'<details class="co-grp"><summary>'
                        f'<div class="co-row co-cust">'
                        f'<div class="co-n">'
                        f'<span class="co-x">&#9654;</span> '
                        f'{email}</div>{cells}</div>'
                        f'</summary>{dh}</details>'
                    )
            st.markdown(
                '<style>'
                '.co-tbl{font-size:13px;width:100%;}'
                '.co-row{display:grid;'
                'grid-template-columns:1fr 100px 90px 70px 60px 55px;'
                'gap:4px;padding:5px 8px;border-bottom:1px solid #333;'
                'align-items:center;}'
                '.co-hdr{background:#2a3f5f;color:#fff;'
                'font-weight:700;border-radius:4px 4px 0 0;}'
                '.co-cust{background:#1E1E1E;}'
                '.co-det{background:#161616;}'
                '.co-tot{background:#2a3f5f;color:#fff;'
                'font-weight:700;border-radius:0 0 4px 4px;}'
                '.co-n{color:#fff;font-weight:700;font-size:12px;'
                'white-space:nowrap;overflow:hidden;'
                'text-overflow:ellipsis;}'
                '.co-ind{padding-left:20px;color:#aaa;'
                'font-weight:400;}'
                '.co-c{text-align:right;color:#ccc;}'
                '.co-grp>summary{list-style:none;cursor:pointer;}'
                '.co-grp>summary::-webkit-details-marker'
                '{display:none;}'
                '.co-grp>summary .co-cust:hover'
                '{background:#2a2a2a;}'
                '.co-x{font-size:9px;color:#888;'
                'display:inline-block;transition:transform 0.15s;}'
                '.co-grp[open] .co-x{transform:rotate(90deg);}'
                '</style>'
                '<div class="co-tbl">'
                '<div class="co-row co-hdr">'
                '<div>Customer</div>'
                '<div class="co-c">Name</div>'
                '<div class="co-c">Net Sales ($)</div>'
                '<div class="co-c">GP ($)</div>'
                '<div class="co-c">Orders</div>'
                '<div class="co-c">Units</div>'
                '</div>'
                + "".join(co_rows)
                + f'<div class="co-row co-tot">'
                f'<div>Total</div><div class="co-c"></div>'
                f'<div class="co-c">${t_ns:,.0f}</div>'
                f'<div class="co-c">${t_gp:,.0f}</div>'
                f'<div class="co-c">{t_or:,}</div>'
                f'<div class="co-c">{t_un:,}</div>'
                f'</div></div>',
                unsafe_allow_html=True,
            )
    else:
        st.info("No data.")

with geo_right:
    st.caption("Map")
    if not df_target.empty and not geo_df.empty:
        from utils.zip3_coords import ZIP3_COORDS

        # Aggregate by postcode for city-level map granularity
        geo_map = geo_df.copy()
        geo_map["ZIP3"] = geo_map["POSTCODE"].astype(str).str[:3]
        map_df = geo_map.groupby(["POSTCODE", "ZIP3", "CITY", "REGION"]).agg(
            NET_SALES=("NET_SALES", "sum"),
            ORDERS=("ORDER_ID", "nunique"),
        ).reset_index()
        map_df["LAT"] = map_df["ZIP3"].map(
            lambda z: ZIP3_COORDS.get(z, (None, None))[0]
        )
        map_df["LON"] = map_df["ZIP3"].map(
            lambda z: ZIP3_COORDS.get(z, (None, None))[1]
        )
        map_df = map_df.dropna(subset=["LAT", "LON"])
        # Jitter postcodes sharing ZIP3 so dots spread out
        import random
        random.seed(42)
        map_df = map_df.copy()
        n = len(map_df)
        map_df["LAT"] = [
            float(lat) + random.uniform(-0.3, 0.3)
            for lat in map_df["LAT"]
        ]
        map_df["LON"] = [
            float(lon) + random.uniform(-0.3, 0.3)
            for lon in map_df["LON"]
        ]
        if not map_df.empty:
            # Normalize bubble size (min 3, max 30)
            max_sales = float(map_df["NET_SALES"].max())
            min_sz, max_sz = 3, 30
            if max_sales > 0:
                map_df["SIZE"] = (
                    min_sz + (map_df["NET_SALES"] / max_sales)
                    * (max_sz - min_sz)
                )
            else:
                map_df["SIZE"] = min_sz
            lat_list = [float(x) for x in map_df["LAT"]]
            lon_list = [float(x) for x in map_df["LON"]]
            size_list = [float(x) for x in map_df["SIZE"]]
            hover_texts = [
                f"{r['CITY']}, {r['REGION']}<br>"
                f"${float(r['NET_SALES']):,.0f} | {int(r['ORDERS'])} orders"
                for _, r in map_df.iterrows()
            ]
            from utils.db import _is_sis
            if _is_sis:
                # SiS: st.map (built-in, no external deps)
                sis_map = pd.DataFrame({
                    "latitude": lat_list,
                    "longitude": lon_list,
                    "size": size_list,
                })
                try:
                    st.map(sis_map, size="size")
                except TypeError:
                    # Older Streamlit without size param
                    st.map(sis_map[["latitude", "longitude"]])
            else:
                # Local: Scattermapbox with CARTO dark tiles
                fig = go.Figure(go.Scattermapbox(
                    lat=lat_list,
                    lon=lon_list,
                    marker=dict(
                        size=size_list,
                        color="#00d4aa",
                        opacity=0.6,
                    ),
                    text=hover_texts,
                    hoverinfo="text",
                ))
                apply_theme(
                    fig, height=350, show_legend=False,
                    margin=dict(l=0, r=0, t=0, b=0),
                )
                fig.update_layout(
                    mapbox=dict(
                        style="carto-darkmatter",
                        center=dict(lat=38, lon=-97),
                        zoom=3,
                    ),
                )
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No geographic data to map.")
    else:
        st.info("No geographic data.")

# --- Store filter UI (rendered at bottom, matches PBI layout) ---
st.divider()
st.markdown("**STOREFRONT**")
sf_ui_cols = st.columns(len(STOREFRONTS))
for i, sf in enumerate(STOREFRONTS):
    with sf_ui_cols[i]:
        st.checkbox(sf, key=f"ty_sf_{sf}")

if store_names:
    st.markdown("**STORE**")
    store_ui_cols = st.columns(len(store_names))
    for i, name in enumerate(store_names):
        with store_ui_cols[i]:
            st.checkbox(name, key=f"ty_store_{name}")

# --- Footer ---
st.divider()
from datetime import datetime, timezone, timedelta
now = datetime.now(timezone(timedelta(hours=-4)))  # Eastern Time (EDT)
if not df_target.empty:
    _lot = df_target["TIMEDATE"].max() if "TIMEDATE" in df_target.columns else df_target["CREATED_AT"].max()
    last_order_fmt = pd.Timestamp(_lot).strftime("%m/%d/%y %H:%M:%S") if pd.notna(_lot) else "--"
    row_count = len(df_target)
    st.caption(
        f"Last Update: {now:%m/%d/%y %H:%M:%S} | "
        f"Last Order: {last_order_fmt} | {row_count:,} line items"
        f" | Data cached 5 min"
    )
else:
    st.caption(f"Last Update: {now:%m/%d/%y %H:%M:%S} | No data for selected filters")
