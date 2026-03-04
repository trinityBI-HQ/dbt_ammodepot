"""Sales Overview — Historical sales dashboard with category pages.

Replaces: SALES OVERVIEW REDSHIFT (Power BI — 168 views, #2) + REALTIME
Source: AD_ANALYTICS.GOLD.F_SALES, D_PRODUCT, D_CUSTOMER, D_STORE
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

# --- Page config ---
st.title("SALES OVERVIEW")

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
          and f.STATUS not in ('closed', 'canceled', 'holded', 'fraud')
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
        ["complete", "processing"],
        default=["complete", "processing"],
    )
with filter_cols[3]:
    metric_toggle = st.radio("Metric", ["$", "GP ($)", "Orders", "Units"], horizontal=True)

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

# --- Storefront filter (Website / GunBroker) ---
storefronts = ["Website", "GunBroker"]
if not df_target.empty:
    available_storefronts = df_target["STOREFRONT"].unique().tolist()
    storefronts = [s for s in storefronts if s in available_storefronts]

storefront_cols = st.columns(len(storefronts) + 1)
with storefront_cols[0]:
    st.caption("STOREFRONT")
selected_storefronts = []
for i, sf in enumerate(storefronts):
    with storefront_cols[i + 1]:
        if st.checkbox(sf, value=True, key=f"so_sf_{sf}"):
            selected_storefronts.append(sf)

if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]

# --- Store filter ---
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
kpi_cols = st.columns(5)
with kpi_cols[0]:
    st.metric("Net Sales ($)", f"${kpi['net_sales']:,.0f}", pct_delta(kpi["net_sales"], kpi_prev["net_sales"]))
    st.caption(f"Avg Ticket: ${avg_ticket:,.2f}")
with kpi_cols[1]:
    st.metric("Gross Profit ($)", f"${kpi['gross_profit']:,.0f}", pct_delta(kpi["gross_profit"], kpi_prev["gross_profit"]))
    st.caption(f"Margin: {margin:.1f}%")
with kpi_cols[2]:
    st.metric("Orders", f"{kpi['orders']:,}", pct_delta(kpi["orders"], kpi_prev["orders"]))
with kpi_cols[3]:
    st.metric("Shipping Revenue ($)", f"${kpi['freight_rev']:,.0f}", pct_delta(kpi["freight_rev"], kpi_prev["freight_rev"]))
    shipping_ns_pct = (kpi["freight_rev"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
    st.caption(f"Shipping/NS: {shipping_ns_pct:.1f}%")
with kpi_cols[4]:
    st.metric("GP After Variable Cost", f"${kpi['gp_after_var']:,.0f}", pct_delta(kpi["gp_after_var"], kpi_prev["gp_after_var"]))
    contrib_margin = (kpi["gp_after_var"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
    st.caption(f"Contribution Margin: {contrib_margin:.1f}%")

st.divider()

# --- Charts row ---
chart_cols = st.columns([3, 3, 3, 3])

# Hourly sales chart (today vs compare) — only for TODAY period
with chart_cols[0]:
    if period == "TODAY":
        st.subheader("Sales ($) / Hourly")
        if not df_target.empty:
            hourly_target = df_target.groupby(df_target["HOUR_BUCKET"].dt.hour)["NET_SALES"].sum().reset_index()
            hourly_target.columns = ["HOUR", "NET_SALES"]
            fig = go.Figure()
            fig.add_trace(go.Bar(x=hourly_target["HOUR"], y=hourly_target["NET_SALES"], name="Today", marker_color="#00d4aa"))
            if not df_compare.empty:
                hourly_compare = df_compare.groupby(df_compare["HOUR_BUCKET"].dt.hour)["NET_SALES"].sum().reset_index()
                hourly_compare.columns = ["HOUR", "NET_SALES"]
                fig.add_trace(go.Scatter(x=hourly_compare["HOUR"], y=hourly_compare["NET_SALES"], name="Yesterday", line=dict(color="gray", dash="dash")))
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=True, legend=dict(orientation="h"))
            fig.update_xaxes(title="Hour", dtick=2)
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data for this period.")
    else:
        # For MTD/YTD — daily sales trend
        st.subheader("Sales ($) / Daily")
        if not df_target.empty:
            daily_target = df_target.groupby(df_target["CREATED_AT"].dt.date)["NET_SALES"].sum().reset_index()
            daily_target.columns = ["DATE", "NET_SALES"]
            fig = go.Figure()
            fig.add_trace(go.Bar(x=daily_target["DATE"], y=daily_target["NET_SALES"], name=period_label, marker_color="#00d4aa"))
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=True, legend=dict(orientation="h"))
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data for this period.")

# Sales by Category (or General Purpose if on a category page)
with chart_cols[1]:
    if category == "General":
        st.subheader("Sales ($) / Category")
        if not df_target.empty:
            cat_df = df_target.groupby("CATEGORY")["NET_SALES"].sum().sort_values(ascending=False).head(8).reset_index()
            if not cat_df.empty:
                fig = px.bar(cat_df, x="NET_SALES", y="CATEGORY", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")
    else:
        st.subheader("Sales ($) / General Purpose")
        if not df_target.empty:
            gp_df = df_target.groupby("GENERAL_PURPOSE")["NET_SALES"].sum().sort_values(ascending=False).head(8).reset_index()
            if not gp_df.empty:
                fig = px.bar(gp_df, x="NET_SALES", y="GENERAL_PURPOSE", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

# Sales by Manufacturer
with chart_cols[2]:
    st.subheader("Sales ($) / Manufacturer")
    if not df_target.empty:
        mfr_df = df_target.groupby("MANUFACTURER")["NET_SALES"].sum().sort_values(ascending=False).head(8).reset_index()
        if not mfr_df.empty:
            fig = px.bar(mfr_df, x="NET_SALES", y="MANUFACTURER", orientation="h", color_discrete_sequence=["#00d4aa"])
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
            fig.update_xaxes(title="")
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data.")

# Sales by Caliber (for ammunition-related categories) or Fulfilled By
with chart_cols[3]:
    if category in ("Ammunition", "Guns", "General"):
        st.subheader("Sales ($) / Caliber")
        if not df_target.empty:
            cal_df = df_target.groupby("CALIBER")["NET_SALES"].sum().sort_values(ascending=False).head(8).reset_index()
            if not cal_df.empty:
                fig = px.bar(cal_df, x="NET_SALES", y="CALIBER", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")
    else:
        st.subheader("Sales ($) / Fulfilled By")
        if not df_target.empty:
            vendor_df = df_target.groupby("VENDOR")["NET_SALES"].sum().sort_values(ascending=False).head(6).reset_index()
            if not vendor_df.empty:
                fig = px.bar(vendor_df, x="NET_SALES", y="VENDOR", orientation="h", color_discrete_sequence=["#00d4aa"])
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
            }),
            hide_index=True,
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
            }),
            hide_index=True,
            use_container_width=True,
        )
    else:
        st.info("No data.")

# --- Footer ---
st.divider()
if not df_target.empty:
    last_order_time = df_target["CREATED_AT"].max()
    row_count = len(df_target)
    st.caption(f"Last Order: {last_order_time} | {row_count:,} line items | {period_label} vs {compare_label} | Data cached for 5 minutes")
