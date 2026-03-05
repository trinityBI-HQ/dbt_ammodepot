"""Sales Overview — Historical sales dashboard with category pages.

Replaces: SALES OVERVIEW REDSHIFT (Power BI — 168 views, #2) + REALTIME
Source: AD_ANALYTICS.GOLD.F_SALES, D_PRODUCT, D_CUSTOMER, D_STORE
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

# --- Page config ---
st.title("SALES OVERVIEW")

# Statuses preselected by default (matches Power BI default filter)
DEFAULT_STATUSES = {"COMPLETE", "PROCESSING", "UNVERIFIED"}


@st.cache_data(ttl=3600)
def load_order_statuses() -> list:
    df = run_query("select distinct upper(STATUS) as STATUS from F_SALES order by STATUS")
    return df["STATUS"].tolist() if not df.empty else []


all_statuses = load_order_statuses()
default_statuses = [s for s in all_statuses if s in DEFAULT_STATUSES]

# --- Category pages (mirrors Power BI 9-page structure) ---
CATEGORIES = [
    "General",
    "Ammunition",
    "Guns",
    "Magazines",
    "Gun Parts",
    "Gear",
    "Optics/Sights",
    "Reloading Components",
    "Prep & Survival",
]


# --- Data loading ---
@st.cache_data(ttl=300)
def load_store_names() -> pd.DataFrame:
    return run_query("select STORE_ID, NAME from D_STORE where IS_ACTIVE = true")


@st.cache_data(ttl=300)
def load_sales_data(start_date: date, end_date: date, statuses: tuple) -> pd.DataFrame:
    status_list = ", ".join(f"'{s}'" for s in statuses)
    sql = f"""
        select
            f.CREATED_AT,
            date_trunc('HOUR', f.CREATED_AT) as HOUR_BUCKET,
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
            f.VENDOR,
            f.PRODUCT_ID,
            f.TESTSKU as SKU,
            f.REGION,
            f.CITY,
            f.POSTCODE,
            coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED) as UNITS,
            p."Attribute Set" as CATEGORY,
            p."Manufacturer" as MANUFACTURER,
            p."Caliber" as CALIBER,
            p."General Purpose" as GENERAL_PURPOSE,
            p."Manufacturer SKU" as MANUFACTURER_SKU,
            p."Product Name" as PRODUCT_NAME
        from F_SALES f
        left join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
        where f.CREATED_AT::date between '{start_date}' and '{end_date}'
          and f.STATUS in ({status_list})
    """
    return run_query(sql)


# --- Filters row 1: Period + Category + Order Status ---
filter_cols = st.columns([2, 3, 3, 4])
with filter_cols[0]:
    period = st.radio("Period", ["TODAY", "MTD", "YTD"], horizontal=True)
with filter_cols[1]:
    category = st.selectbox("Category", CATEGORIES)
with filter_cols[2]:
    order_status = st.multiselect(
        "Order Status",
        all_statuses,
        default=default_statuses,
    )
with filter_cols[3]:
    metric_toggle = st.radio("Metric", ["$", "GP ($)", "Orders", "Units"], horizontal=True)

# Metric mapping
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
    start_date = today
    end_date = today
    compare_start = today - timedelta(days=1)
    compare_end = today - timedelta(days=1)
    period_label = "Today"
    compare_label = "Yesterday"
elif period == "MTD":
    start_date = today.replace(day=1)
    end_date = today
    prev_month_end = start_date - timedelta(days=1)
    compare_start = prev_month_end.replace(day=1)
    compare_end = prev_month_end.replace(day=min(today.day, prev_month_end.day))
    period_label = f"MTD ({start_date:%b})"
    compare_label = f"Prev MTD ({compare_start:%b})"
else:  # YTD
    start_date = today.replace(month=1, day=1)
    end_date = today
    compare_start = date(today.year - 1, 1, 1)
    compare_end = date(today.year - 1, today.month, today.day)
    period_label = f"YTD {today.year}"
    compare_label = f"YTD {today.year - 1}"

# --- Load data ---
statuses = tuple(order_status) if order_status else ("complete",)
store_df = load_store_names()

df_target = load_sales_data(start_date, end_date, statuses)
df_compare = load_sales_data(compare_start, compare_end, statuses)

# --- Storefront filter (always show Website + GunBroker) ---
STOREFRONTS = ["Website", "GunBroker"]
sf_cols = st.columns(len(STOREFRONTS) + 1)
with sf_cols[0]:
    st.caption("STOREFRONT")
selected_storefronts = []
for i, sf in enumerate(STOREFRONTS):
    with sf_cols[i + 1]:
        if st.checkbox(sf, value=True, key=f"so_sf_{sf}"):
            selected_storefronts.append(sf)
if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]

# --- Store filter (all stores, matching Power BI) ---
store_names = store_df["NAME"].tolist() if not store_df.empty else []
if store_names:
    store_cols = st.columns(len(store_names) + 1)
    with store_cols[0]:
        st.caption("STORE")
    selected_store_ids = []
    for i, name in enumerate(store_names):
        with store_cols[i + 1]:
            if st.checkbox(name, value=True, key=f"so_store_{name}"):
                sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
                selected_store_ids.append(sid)

    if selected_store_ids and not df_target.empty:
        df_target = df_target[df_target["STORE_ID"].isin(selected_store_ids)]
        df_compare = df_compare[df_compare["STORE_ID"].isin(selected_store_ids)]

# --- Category filter ---
if category != "General" and not df_target.empty:
    df_target = df_target[df_target["CATEGORY"] == category]
    df_compare = df_compare[df_compare["CATEGORY"] == category]

# --- Additional filters row (Vendor + Product Name) ---
if not df_target.empty:
    adv_cols = st.columns([3, 3, 6])
    with adv_cols[0]:
        vendors = sorted(df_target["VENDOR"].dropna().unique().tolist())
        selected_vendors = st.multiselect("Vendor", vendors, key="so_vendor")
    with adv_cols[1]:
        products = sorted(df_target["PRODUCT_NAME"].dropna().unique().tolist())
        selected_products = st.multiselect("Product Name", products, key="so_product")

    if selected_vendors:
        df_target = df_target[df_target["VENDOR"].isin(selected_vendors)]
        df_compare = df_compare[df_compare["VENDOR"].isin(selected_vendors)]
    if selected_products:
        df_target = df_target[df_target["PRODUCT_NAME"].isin(selected_products)]
        df_compare = df_compare[df_compare["PRODUCT_NAME"].isin(selected_products)]


# --- KPI calculations ---
def calc_kpis(df: pd.DataFrame) -> dict:
    if df.empty:
        return {
            "net_sales": 0, "cost": 0, "gross_profit": 0,
            "orders": 0, "units": 0, "freight_rev": 0,
            "freight_cost": 0, "gp_after_var": 0,
        }
    net_sales = df["NET_SALES"].sum()
    cost = df["COST"].sum()
    gross_profit = net_sales - cost
    freight_rev = df["FREIGHT_REVENUE"].sum()
    freight_cost = df["FREIGHT_COST"].sum()
    return {
        "net_sales": net_sales,
        "cost": cost,
        "gross_profit": gross_profit,
        "orders": df["ORDER_ID"].nunique(),
        "units": df["UNITS"].sum(),
        "freight_rev": freight_rev,
        "freight_cost": freight_cost,
        "gp_after_var": gross_profit - freight_cost,
    }


kpi = calc_kpis(df_target)
kpi_prev = calc_kpis(df_compare)

margin = (kpi["gross_profit"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
avg_ticket = (kpi["net_sales"] / kpi["orders"]) if kpi["orders"] else 0


def pct_delta(current, previous):
    if previous and previous != 0:
        return f"{((current - previous) / abs(previous)) * 100:+.1f}%"
    return None


# --- KPI Row ---
st.divider()

shipping_ns_pct = (kpi["freight_rev"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
contrib_margin = (kpi["gp_after_var"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0

kpi_cards = [
    {
        "icon": "&#x1F4B2;",
        "color": "#00B4D8",
        "title": "Net Sales",
        "value": f"${kpi['net_sales']:,.0f}",
        "delta": pct_delta(kpi["net_sales"], kpi_prev["net_sales"]),
        "sub_label": "Avg Ticket",
        "sub_value": f"${avg_ticket:,.2f}",
    },
    {
        "icon": "&#x1F4C8;",
        "color": "#2DC653",
        "title": "Gross Profit",
        "value": f"${kpi['gross_profit']:,.0f}",
        "delta": pct_delta(kpi["gross_profit"], kpi_prev["gross_profit"]),
        "sub_label": "Margin",
        "sub_value": f"{margin:.1f}%",
    },
    {
        "icon": "&#x1F6D2;",
        "color": "#00B4D8",
        "title": "Orders",
        "value": f"{kpi['orders']:,}",
        "delta": pct_delta(kpi["orders"], kpi_prev["orders"]),
        "sub_label": "Orders/Day",
        "sub_value": f"{kpi['orders']}",
    },
    {
        "icon": "&#x1F69A;",
        "color": "#2DC653",
        "title": "Shipping Revenue",
        "value": f"${kpi['freight_rev']:,.0f}",
        "delta": pct_delta(kpi["freight_rev"], kpi_prev["freight_rev"]),
        "sub_label": "Shipping/NS",
        "sub_value": f"{shipping_ns_pct:.1f}%",
    },
    {
        "icon": "&#x1F6E1;",
        "color": "#00B4D8",
        "title": "GP After Var Cost",
        "value": f"${kpi['gp_after_var']:,.0f}",
        "delta": pct_delta(kpi["gp_after_var"], kpi_prev["gp_after_var"]),
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

# --- Charts row ---
chart_cols = st.columns([3, 3, 3, 3])

# Helper: compute GP column and aggregate by metric


def _add_gp(df):
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    return df


def _agg_metric(df, group_col, metric):
    if df.empty:
        return pd.DataFrame()
    df = _add_gp(df)
    if metric == "Orders":
        r = df.groupby(group_col)["ORDER_ID"].nunique().reset_index()
    elif metric == "Units":
        r = df.groupby(group_col)["UNITS"].sum().reset_index()
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        r = df.groupby(group_col)[col].sum().reset_index()
    r.columns = [group_col, "VALUE"]
    return r.sort_values("VALUE", ascending=False)


# Helper: aggregate by time bucket (Series-based groupby)
def _agg_time_metric(df, time_series, metric):
    if df.empty:
        return pd.DataFrame(columns=["BUCKET", "VALUE"])
    df = _add_gp(df)
    if metric == "Orders":
        r = df.groupby(time_series)["ORDER_ID"].nunique()
    elif metric == "Units":
        r = df.groupby(time_series)["UNITS"].sum()
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        r = df.groupby(time_series)[col].sum()
    return r.reset_index().set_axis(["BUCKET", "VALUE"], axis=1)


# Hourly/Daily chart — metric-aware
with chart_cols[0]:
    if period == "TODAY":
        st.subheader(f"{metric_label} / Hourly")
        if not df_target.empty:
            hourly_target = _agg_time_metric(df_target, df_target["HOUR_BUCKET"].dt.hour, metric_toggle)
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=hourly_target["BUCKET"], y=hourly_target["VALUE"],
                name="Today", marker_color="#00d4aa",
            ))
            if not df_compare.empty:
                hourly_compare = _agg_time_metric(
                    df_compare, df_compare["HOUR_BUCKET"].dt.hour, metric_toggle,
                )
                fig.add_trace(go.Scatter(
                    x=hourly_compare["BUCKET"], y=hourly_compare["VALUE"],
                    name="Yesterday", line=dict(color="gray", dash="dash"),
                ))
            fig.update_layout(
                height=300, margin=dict(l=0, r=0, t=10, b=0),
                showlegend=True, legend=dict(orientation="h"),
            )
            fig.update_xaxes(title="Hour", dtick=2)
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data for this period.")
    else:
        st.subheader(f"{metric_label} / Daily")
        if not df_target.empty:
            daily_target = _agg_time_metric(df_target, df_target["CREATED_AT"].dt.date, metric_toggle)
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=daily_target["BUCKET"], y=daily_target["VALUE"],
                name=period_label, marker_color="#00d4aa",
            ))
            fig.update_layout(
                height=300, margin=dict(l=0, r=0, t=10, b=0),
                showlegend=True, legend=dict(orientation="h"),
            )
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data for this period.")

# Category / General Purpose chart — metric-aware
with chart_cols[1]:
    if category == "General":
        st.subheader(f"{metric_label} / Category")
        if not df_target.empty:
            cat_agg = _agg_metric(df_target, "CATEGORY", metric_toggle).head(8)
            if not cat_agg.empty:
                fig = go.Figure(go.Bar(x=cat_agg["VALUE"].tolist(), y=cat_agg["CATEGORY"].tolist(), orientation="h", marker_color="#00d4aa"))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")
    else:
        st.subheader(f"{metric_label} / General Purpose")
        if not df_target.empty:
            gp_agg = _agg_metric(df_target, "GENERAL_PURPOSE", metric_toggle).head(8)
            if not gp_agg.empty:
                fig = go.Figure(go.Bar(x=gp_agg["VALUE"].tolist(), y=gp_agg["GENERAL_PURPOSE"].tolist(), orientation="h", marker_color="#00d4aa"))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

# Manufacturer chart — metric-aware
with chart_cols[2]:
    st.subheader(f"{metric_label} / Manufacturer")
    if not df_target.empty:
        mfr_agg = _agg_metric(df_target, "MANUFACTURER", metric_toggle).head(8)
        if not mfr_agg.empty:
            fig = go.Figure(go.Bar(x=mfr_agg["VALUE"].tolist(), y=mfr_agg["MANUFACTURER"].tolist(), orientation="h", marker_color="#00d4aa"))
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
            fig.update_xaxes(title="")
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data.")

# Caliber / Fulfilled By chart — metric-aware
with chart_cols[3]:
    if category in ("Ammunition", "Guns", "General"):
        st.subheader(f"{metric_label} / Caliber")
        if not df_target.empty:
            cal_agg = _agg_metric(df_target, "CALIBER", metric_toggle).head(8)
            if not cal_agg.empty:
                fig = go.Figure(go.Bar(x=cal_agg["VALUE"].tolist(), y=cal_agg["CALIBER"].tolist(), orientation="h", marker_color="#00d4aa"))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")
    else:
        st.subheader(f"{metric_label} / Fulfilled By")
        if not df_target.empty:
            vendor_agg = _agg_metric(df_target, "VENDOR", metric_toggle).head(6)
            if not vendor_agg.empty:
                fig = go.Figure(go.Bar(x=vendor_agg["VALUE"].tolist(), y=vendor_agg["VENDOR"].tolist(), orientation="h", marker_color="#00d4aa"))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

st.divider()

# --- Tables row ---
table_cols = st.columns(2)

with table_cols[0]:
    st.subheader(f"Product Performance / {period_label}")
    if not df_target.empty:
        product_perf = (
            df_target.groupby(["SKU", "MANUFACTURER_SKU"])
            .agg(
                NET_SALES=("NET_SALES", "sum"),
                COST=("COST", "sum"),
                ORDERS=("ORDER_ID", "nunique"),
                UNITS=("UNITS", "sum"),
            )
            .reset_index()
        )
        product_perf["GP"] = product_perf["NET_SALES"] - product_perf["COST"]
        product_perf["MARGIN"] = (product_perf["GP"] / product_perf["NET_SALES"] * 100).round(2)
        product_perf["PRICE/UNIT"] = (product_perf["NET_SALES"] / product_perf["UNITS"]).round(2)
        product_perf = product_perf.sort_values("NET_SALES", ascending=False).head(25)
        display_cols = ["MANUFACTURER_SKU", "SKU", "NET_SALES", "GP", "ORDERS", "UNITS", "MARGIN", "PRICE/UNIT"]
        st.dataframe(
            product_perf[display_cols].style.format({
                "NET_SALES": "${:,.2f}",
                "GP": "${:,.2f}",
                "MARGIN": "{:.2f}%",
                "PRICE/UNIT": "${:,.2f}",
            }).hide(axis="index"),
            use_container_width=True,
        )
    else:
        st.info("No data.")

with table_cols[1]:
    st.subheader(f"Customer Overview / {period_label}")
    if not df_target.empty:
        customer_perf = (
            df_target.groupby(["CUSTOMER_EMAIL", "CUSTOMER_NAME"])
            .agg(
                NET_SALES=("NET_SALES", "sum"),
                COST=("COST", "sum"),
                ORDERS=("ORDER_ID", "nunique"),
                UNITS=("UNITS", "sum"),
            )
            .reset_index()
        )
        customer_perf["GP"] = customer_perf["NET_SALES"] - customer_perf["COST"]
        customer_perf = customer_perf.sort_values("NET_SALES", ascending=False).head(25)
        display_cols = ["CUSTOMER_EMAIL", "CUSTOMER_NAME", "NET_SALES", "GP", "ORDERS", "UNITS"]
        st.dataframe(
            customer_perf[display_cols].style.format({
                "NET_SALES": "${:,.2f}",
                "GP": "${:,.2f}",
            }).hide(axis="index"),
            use_container_width=True,
        )
    else:
        st.info("No data.")

# --- Footer ---
st.divider()
if not df_target.empty:
    last_order_time = df_target["CREATED_AT"].max()
    row_count = len(df_target)
    st.caption(
        f"Last Order: {last_order_time} | {row_count:,} line items"
        f" | {period_label} vs {compare_label} | Data cached 5 min"
    )
