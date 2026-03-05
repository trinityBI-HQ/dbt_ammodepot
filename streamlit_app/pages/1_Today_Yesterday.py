"""Today / Yesterday — Real-time sales dashboard.

Replaces: SALES OVERVIEW FASTER (Power BI — 1,188 views, #1 most used)
Source: AD_ANALYTICS.GOLD.F_SALES
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

# --- Page config ---
st.title("SALES OVERVIEW: TODAY / YESTERDAY")

# --- Filters ---
filter_cols = st.columns([2, 2, 2, 2, 4])
with filter_cols[0]:
    period = st.radio("Period", ["TODAY", "Yesterday"], horizontal=True)
with filter_cols[1]:
    order_status = st.multiselect(
        "Order Status",
        ["COMPLETE", "PROCESSING"],
        default=["COMPLETE", "PROCESSING"],
    )
with filter_cols[2]:
    metric_toggle = st.radio("Metric", ["$", "GP ($)", "Orders", "Units"], horizontal=True)

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
            CREATED_AT,
            date_trunc('HOUR', CREATED_AT) as HOUR_BUCKET,
            INCREMENT_ID as ORDER_ID,
            CUSTOMER_EMAIL,
            CUSTOMER_NAME,
            STORE_ID,
            STOREFRONT,
            STATUS,
            ROW_TOTAL as NET_SALES,
            COST,
            QTY_ORDERED,
            FREIGHT_REVENUE,
            FREIGHT_COST,
            VENDOR,
            PRODUCT_ID,
            TESTSKU as SKU,
            PART_QTY_SOLD as UNITS
        from F_SALES
        where CREATED_AT::date = '{dt}'
          and STATUS in ({status_list})
          and STATUS not in ('CLOSED', 'CANCELED', 'HOLDED', 'FRAUD')
    """
    return run_query(sql)


@st.cache_data(ttl=3600)
def load_store_names() -> pd.DataFrame:
    return run_query("select STORE_ID, NAME from D_STORE where IS_ACTIVE = true")


store_df = load_store_names()
statuses = tuple(order_status) if order_status else ("complete",)
df_target = load_sales(target_date, statuses)
df_compare = load_sales(compare_date, statuses)

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
        if st.checkbox(sf, value=True, key=f"sf_{sf}"):
            selected_storefronts.append(sf)

if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]

# --- Store filter ---
store_names = store_df["NAME"].tolist()
store_cols = st.columns(len(store_names) + 1)
with store_cols[0]:
    st.caption("STORE")
selected_store_ids = []
for i, name in enumerate(store_names):
    with store_cols[i + 1]:
        if st.checkbox(name, value=True, key=f"store_{name}"):
            sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
            selected_store_ids.append(sid)

if selected_store_ids and not df_target.empty:
    df_target = df_target[df_target["STORE_ID"].isin(selected_store_ids)]
    df_compare = df_compare[df_compare["STORE_ID"].isin(selected_store_ids)]

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
kpi_cols = st.columns(5)
with kpi_cols[0]:
    st.metric("Net Sales ($)", f"${net_sales:,.0f}", pct_delta(net_sales, net_sales_prev))
    st.caption(f"Avg Ticket: ${avg_ticket:,.2f}")
with kpi_cols[1]:
    st.metric("Gross Profit ($)", f"${gross_profit:,.0f}", pct_delta(gross_profit, gp_prev))
    st.caption(f"Margin: {margin:.1f}%")
with kpi_cols[2]:
    st.metric("Orders", f"{orders:,}", pct_delta(orders, orders_prev))
    st.caption(f"Orders/Day: {orders_per_day}")
with kpi_cols[3]:
    st.metric("Shipping Revenue ($)", f"${freight_rev:,.0f}", pct_delta(freight_rev, freight_rev_prev))
    shipping_ns_pct = (freight_rev / net_sales * 100) if net_sales else 0
    st.caption(f"Shipping/NS: {shipping_ns_pct:.1f}%")
with kpi_cols[4]:
    st.metric("GP After Variable Cost", f"${gp_after_var:,.0f}", pct_delta(gp_after_var, gp_after_var_prev))
    contrib_margin = (gp_after_var / net_sales * 100) if net_sales else 0
    st.caption(f"Contribution Margin: {contrib_margin:.1f}%")

st.divider()

# --- Charts row ---
chart_cols = st.columns([3, 3, 3, 3])

# Hourly sales chart (today vs compare)
with chart_cols[0]:
    st.subheader("Sales ($) / Hourly")
    if not df_target.empty:
        hourly_target = df_target.groupby(df_target["HOUR_BUCKET"].dt.hour)["NET_SALES"].sum().reset_index()
        hourly_target.columns = ["HOUR", "NET_SALES"]
        fig = go.Figure()
        fig.add_trace(go.Bar(x=hourly_target["HOUR"], y=hourly_target["NET_SALES"], name=period, marker_color="#00d4aa"))
        if not df_compare.empty:
            hourly_compare = df_compare.groupby(df_compare["HOUR_BUCKET"].dt.hour)["NET_SALES"].sum().reset_index()
            hourly_compare.columns = ["HOUR", "NET_SALES"]
            fig.add_trace(go.Scatter(x=hourly_compare["HOUR"], y=hourly_compare["NET_SALES"], name="Previous", line=dict(color="gray", dash="dash")))
        fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=True, legend=dict(orientation="h"))
        fig.update_xaxes(title="Hour", dtick=2)
        fig.update_yaxes(title="")
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data for this period.")

# Sales by Category
with chart_cols[1]:
    st.subheader("Sales ($) / Category")
    if not df_target.empty:
        cat_sql = f"""
            select p.CATEGORY, sum(f.ROW_TOTAL) as NET_SALES
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT::date = '{target_date}'
              and f.STATUS in ({", ".join(f"'{s}'" for s in statuses)})
              and f.STATUS not in ('CLOSED', 'CANCELED', 'HOLDED', 'FRAUD')
            group by p.CATEGORY
            order by NET_SALES desc
            limit 8
        """
        cat_df = run_query(cat_sql)
        if not cat_df.empty:
            fig = px.bar(cat_df, x="NET_SALES", y="CATEGORY", orientation="h", color_discrete_sequence=["#00d4aa"])
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
            fig.update_xaxes(title="")
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data.")

# Sales by Fulfilled By (vendor)
with chart_cols[2]:
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

# Sales by Manufacturer (SKU prefix)
with chart_cols[3]:
    st.subheader("Sales ($) / Manufacturer")
    if not df_target.empty:
        mfr_sql = f"""
            select p.MANUFACTURER, sum(f.ROW_TOTAL) as NET_SALES
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT::date = '{target_date}'
              and f.STATUS in ({", ".join(f"'{s}'" for s in statuses)})
              and f.STATUS not in ('CLOSED', 'CANCELED', 'HOLDED', 'FRAUD')
            group by p.MANUFACTURER
            order by NET_SALES desc
            limit 8
        """
        mfr_df = run_query(mfr_sql)
        if not mfr_df.empty:
            fig = px.bar(mfr_df, x="NET_SALES", y="MANUFACTURER", orientation="h", color_discrete_sequence=["#00d4aa"])
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
    st.subheader(f"Product Performance / {period}")
    if not df_target.empty:
        product_perf = (
            df_target.groupby("SKU")
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
        product_perf = product_perf.sort_values("NET_SALES", ascending=False).head(20)
        display_cols = ["SKU", "NET_SALES", "GP", "ORDERS", "UNITS", "MARGIN", "PRICE/UNIT"]
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
    st.subheader(f"Customer Overview / {period}")
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
        customer_perf = customer_perf.sort_values("NET_SALES", ascending=False).head(20)
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
    st.caption(f"Last Order: {last_order_time} | Data cached for 5 minutes")
