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

# Statuses to exclude by default (matches Power BI default filter)
EXCLUDED_STATUSES = {"CLOSED", "HOLDED", "CANCELED", "FRAUD"}


@st.cache_data(ttl=3600)
def load_order_statuses() -> list:
    df = run_query("select distinct upper(STATUS) as STATUS from F_SALES order by STATUS")
    return df["STATUS"].tolist() if not df.empty else []


all_statuses = load_order_statuses()
default_statuses = [s for s in all_statuses if s not in EXCLUDED_STATUSES]

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
            CREATED_AT,
            TIMEDATE,
            date_trunc('HOUR', TIMEDATE) as HOUR_BUCKET,
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
            PART_QTY_SOLD as UNITS,
            REGION,
            CITY,
            POSTCODE
        from F_SALES
        where CREATED_AT = '{dt}'
          and STATUS in ({status_list})
    """
    return run_query(sql)


@st.cache_data(ttl=300)
def load_sales_range(start_dt: date, end_dt: date, statuses: tuple) -> pd.DataFrame:
    status_list = ", ".join(f"'{s}'" for s in statuses)
    sql = f"""
        select
            CREATED_AT,
            TIMEDATE,
            date_trunc('HOUR', TIMEDATE) as HOUR_BUCKET,
            INCREMENT_ID as ORDER_ID,
            STORE_ID,
            STOREFRONT,
            STATUS,
            ROW_TOTAL as NET_SALES,
            COST,
            coalesce(PART_QTY_SOLD, QTY_ORDERED) as UNITS
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
            date_trunc('HOUR', TIMEDATE) as HOUR_BUCKET,
            INCREMENT_ID as ORDER_ID,
            ROW_TOTAL as NET_SALES,
            COST,
            coalesce(PART_QTY_SOLD, QTY_ORDERED) as UNITS,
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

# --- Storefront filter (always show Website + GunBroker) ---
STOREFRONTS = ["Website", "GunBroker"]
sf_cols = st.columns(len(STOREFRONTS) + 1)
with sf_cols[0]:
    st.caption("STOREFRONT")
selected_storefronts = []
for i, sf in enumerate(STOREFRONTS):
    with sf_cols[i + 1]:
        if st.checkbox(sf, value=True, key=f"ty_sf_{sf}"):
            selected_storefronts.append(sf)
if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]
    if not df_last_month.empty:
        df_last_month = df_last_month[
            df_last_month["STOREFRONT"].isin(selected_storefronts)
        ]

# --- Store filter (all stores, matching Power BI) ---
store_names = store_df["NAME"].tolist() if not store_df.empty else []
selected_store_ids = []
if store_names:
    store_cols = st.columns(len(store_names) + 1)
    with store_cols[0]:
        st.caption("STORE")
    for i, name in enumerate(store_names):
        with store_cols[i + 1]:
            if st.checkbox(name, value=True, key=f"store_{name}"):
                sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
                selected_store_ids.append(sid)

    if selected_store_ids and not df_target.empty:
        df_target = df_target[df_target["STORE_ID"].isin(selected_store_ids)]
        df_compare = df_compare[df_compare["STORE_ID"].isin(selected_store_ids)]
        if not df_last_month.empty:
            df_last_month = df_last_month[
                df_last_month["STORE_ID"].isin(selected_store_ids)
            ]

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
    hour_series = pd.to_datetime(df["HOUR_BUCKET"]).dt.hour
    if metric == "Orders":
        r = df.groupby(hour_series)["ORDER_ID"].nunique()
    elif metric == "Units":
        r = df.groupby(hour_series)["UNITS"].sum()
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        r = df.groupby(hour_series)[col].sum()
    result = r.reset_index().set_axis(["HOUR", "VALUE"], axis=1)
    result["HOUR_LABEL"] = result["HOUR"].apply(_hour_label)
    return result


def _hourly_avg(df, metric):
    """Compute average hourly values across multiple days (for LM line)."""
    if df.empty:
        return pd.DataFrame(columns=["HOUR", "HOUR_LABEL", "VALUE"])
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    df["HOUR"] = pd.to_datetime(df["HOUR_BUCKET"]).dt.hour
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
chart_cols = st.columns([4, 3, 3, 3])

# Analytical View chart (first column — switches between Hourly / Bar Chart / Heat Map)
with chart_cols[0]:
    if analytical_view == "Hourly":
        st.subheader(f"{metric_label} / Hourly")
        if not df_target.empty:
            hourly_target = _hourly_agg(df_target, metric_toggle)
            fig = go.Figure()
            fig.add_trace(go.Scatter(
                x=hourly_target["HOUR_LABEL"],
                y=hourly_target["VALUE"],
                name=period, marker_color="#00d4aa",
                mode="lines+markers",
                marker=dict(size=6),
            ))
            if not df_compare.empty:
                hourly_compare = _hourly_agg(df_compare, metric_toggle)
                fig.add_trace(go.Scatter(
                    x=hourly_compare["HOUR_LABEL"],
                    y=hourly_compare["VALUE"],
                    name="YESTERDAY",
                    line=dict(color="gray", dash="dash"),
                ))
            # Average LM (last 30 days average)
            lm_avg = None
            if not df_last_month.empty:
                hourly_lm = _hourly_avg(df_last_month, metric_toggle)
                if not hourly_lm.empty:
                    lm_avg = hourly_lm["VALUE"].mean()
                    fig.add_trace(go.Scatter(
                        x=hourly_lm["HOUR_LABEL"],
                        y=hourly_lm["VALUE"],
                        name="Average LM",
                        line=dict(color="gray", dash="dot", width=1),
                        mode="lines",
                    ))
            # Average line for target day
            target_avg = hourly_target["VALUE"].mean()
            fig.add_hline(
                y=target_avg, line_dash="dot", line_color="#00d4aa",
                line_width=1,
            )
            # Summary below chart header
            avg_text = f"Average  **{target_avg:,.0f}**"
            if lm_avg is not None:
                avg_text += f"  &nbsp;·&nbsp;  Average LM  **{lm_avg:,.2f}**"
            fig.update_layout(
                height=300, margin=dict(l=0, r=0, t=30, b=0),
                showlegend=True,
                legend=dict(
                    orientation="h",
                    yanchor="bottom", y=1.02,
                    xanchor="left", x=0,
                    font=dict(size=11),
                ),
                xaxis=dict(
                    categoryorder="array",
                    categoryarray=[_hour_label(h) for h in range(24)],
                ),
            )
            fig.update_xaxes(title="Hour")
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
            fig.add_trace(go.Bar(x=daily["DAY"], y=daily[val_col], name=metric_label, marker_color="#00d4aa"))
            fig.add_trace(go.Scatter(
                x=daily["DAY"], y=daily["MARGIN"], name="Margin %", yaxis="y2",
                mode="lines+markers+text",
                text=[f"{m:.0f}%" for m in daily["MARGIN"]],
                textposition="top center", line=dict(color="#4CAF50"),
            ))
            fig.update_layout(
                height=300, margin=dict(l=0, r=40, t=10, b=0),
                yaxis2=dict(title="Margin %", overlaying="y", side="right", range=[0, 100]),
                showlegend=True, legend=dict(orientation="h"),
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
            df_heat["HOUR"] = pd.to_datetime(df_heat["HOUR_BUCKET"]).dt.hour
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
                z=pivot.values,
                x=[_hour_label(h) for h in pivot.columns],
                y=dow_labels,
                colorscale="Greens",
                hoverongaps=False,
            ))
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0))
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


# Category chart
with chart_cols[1]:
    st.subheader(f"{metric_label} / Category")
    if not df_target.empty:
        cat_sql = f"""
            select p."Attribute Set" as CATEGORY,
                   sum(f.ROW_TOTAL) as NET_SALES,
                   sum(f.COST) as COST,
                   count(distinct f.INCREMENT_ID) as ORDERS,
                   sum(coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED)) as UNITS
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT::date = '{target_date}'
              and f.STATUS in ({", ".join(f"'{s}'" for s in statuses)})
            group by p."Attribute Set"
            order by NET_SALES desc
            limit 8
        """
        cat_df = run_query(cat_sql)
        if not cat_df.empty:
            cat_df["GP"] = cat_df["NET_SALES"] - cat_df["COST"]
            val_col = {"$": "NET_SALES", "GP ($)": "GP", "Orders": "ORDERS", "Units": "UNITS"}[metric_toggle]
            cat_df = cat_df.sort_values(val_col, ascending=False)
            fig = px.bar(cat_df, x=val_col, y="CATEGORY", orientation="h", color_discrete_sequence=["#00d4aa"])
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
            fig.update_xaxes(title="")
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data.")

# Fulfilled By chart
with chart_cols[2]:
    st.subheader(f"{metric_label} / Fulfilled By")
    if not df_target.empty:
        vendor_agg = agg_by_metric(df_target, "VENDOR", metric_toggle).head(6)
        if not vendor_agg.empty:
            fig = px.bar(vendor_agg, x="VALUE", y="VENDOR", orientation="h", color_discrete_sequence=["#00d4aa"])
            fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
            fig.update_xaxes(title="")
            fig.update_yaxes(title="")
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No data.")

# Manufacturer chart
with chart_cols[3]:
    st.subheader(f"{metric_label} / Manufacturer")
    if not df_target.empty:
        mfr_sql = f"""
            select p."Manufacturer" as MANUFACTURER,
                   sum(f.ROW_TOTAL) as NET_SALES,
                   sum(f.COST) as COST,
                   count(distinct f.INCREMENT_ID) as ORDERS,
                   sum(coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED)) as UNITS
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT::date = '{target_date}'
              and f.STATUS in ({", ".join(f"'{s}'" for s in statuses)})
            group by p."Manufacturer"
            order by NET_SALES desc
            limit 8
        """
        mfr_df = run_query(mfr_sql)
        if not mfr_df.empty:
            mfr_df["GP"] = mfr_df["NET_SALES"] - mfr_df["COST"]
            val_col = {"$": "NET_SALES", "GP ($)": "GP", "Orders": "ORDERS", "Units": "UNITS"}[metric_toggle]
            mfr_df = mfr_df.sort_values(val_col, ascending=False)
            fig = px.bar(mfr_df, x=val_col, y="MANUFACTURER", orientation="h", color_discrete_sequence=["#00d4aa"])
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
                S_REVENUE=("FREIGHT_REVENUE", "sum"),
            )
            .reset_index()
        )
        product_perf["GP"] = product_perf["NET_SALES"] - product_perf["COST"]
        product_perf["MARGIN"] = (product_perf["GP"] / product_perf["NET_SALES"] * 100).round(2)
        product_perf["PRICE/UNIT"] = (product_perf["NET_SALES"] / product_perf["UNITS"]).round(2)
        product_perf = product_perf.sort_values("NET_SALES", ascending=False).head(20)
        display_cols = ["SKU", "NET_SALES", "GP", "ORDERS", "UNITS", "MARGIN", "PRICE/UNIT", "S_REVENUE"]
        st.dataframe(
            product_perf[display_cols].style.format({
                "NET_SALES": "${:,.2f}",
                "GP": "${:,.2f}",
                "MARGIN": "{:.2f}%",
                "PRICE/UNIT": "${:,.2f}",
                "S_REVENUE": "${:,.2f}",
            }).hide(axis="index"),
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
            }).hide(axis="index"),
            use_container_width=True,
        )
    else:
        st.info("No data.")

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
            st.dataframe(
                geo_display[cols].style.format({
                    "NET_SALES": "${:,.0f}", "GP": "${:,.0f}", "MARGIN": "{:.2f}%",
                }).hide(axis="index"),
                use_container_width=True, height=250,
            )
        else:  # Customer
            st.caption(f"Customer Overview / {period}")
            cust_agg = (
                geo_df.groupby(["CUSTOMER_EMAIL", "CUSTOMER_NAME"])
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"))
                .reset_index()
            )
            cust_agg["GP"] = cust_agg["NET_SALES"] - cust_agg["COST"]
            cust_agg = cust_agg.sort_values("NET_SALES", ascending=False)

            totals = pd.DataFrame([{
                "CUSTOMER_EMAIL": "Total", "CUSTOMER_NAME": "",
                "NET_SALES": cust_agg["NET_SALES"].sum(),
                "GP": cust_agg["GP"].sum(),
                "ORDERS": cust_agg["ORDERS"].sum(),
                "UNITS": cust_agg["UNITS"].sum(),
            }])
            cust_display = pd.concat([cust_agg, totals], ignore_index=True)
            cols = ["CUSTOMER_EMAIL", "CUSTOMER_NAME", "NET_SALES", "GP", "ORDERS", "UNITS"]
            st.dataframe(
                cust_display[cols].style.format({
                    "NET_SALES": "${:,.0f}", "GP": "${:,.0f}",
                }).hide(axis="index"),
                use_container_width=True, height=250,
            )
    else:
        st.info("No data.")

with geo_right:
    st.caption("Map")
    if not df_target.empty and not geo_df.empty:
        # US state name → (lat, lon) centroids for map placement
        US_STATE_COORDS = {
            "Alabama": (32.8, -86.8), "Alaska": (64.2, -152.5),
            "Arizona": (34.0, -111.1), "Arkansas": (35.2, -91.8),
            "California": (36.8, -119.4), "Colorado": (39.1, -105.4),
            "Connecticut": (41.6, -72.7), "Delaware": (39.0, -75.5),
            "Florida": (27.8, -81.8), "Georgia": (33.0, -83.5),
            "Hawaii": (19.9, -155.6), "Idaho": (44.2, -114.4),
            "Illinois": (40.3, -89.0), "Indiana": (40.3, -86.1),
            "Iowa": (42.0, -93.2), "Kansas": (38.5, -98.8),
            "Kentucky": (37.8, -84.3), "Louisiana": (30.5, -91.2),
            "Maine": (45.3, -69.4), "Maryland": (39.0, -76.6),
            "Massachusetts": (42.4, -71.4), "Michigan": (44.3, -84.5),
            "Minnesota": (46.4, -94.6), "Mississippi": (32.7, -89.7),
            "Missouri": (37.9, -91.8), "Montana": (46.8, -110.4),
            "Nebraska": (41.5, -99.9), "Nevada": (38.8, -116.4),
            "New Hampshire": (43.2, -71.6), "New Jersey": (40.1, -74.5),
            "New Mexico": (34.5, -106.0), "New York": (43.0, -75.5),
            "North Carolina": (35.6, -79.0), "North Dakota": (47.5, -100.5),
            "Ohio": (40.4, -82.9), "Oklahoma": (35.0, -97.1),
            "Oregon": (43.8, -120.6), "Pennsylvania": (41.2, -77.2),
            "Rhode Island": (41.6, -71.5), "South Carolina": (34.0, -81.2),
            "South Dakota": (43.9, -99.9), "Tennessee": (35.5, -86.6),
            "Texas": (31.1, -97.6), "Utah": (39.3, -111.1),
            "Vermont": (44.6, -72.6), "Virginia": (37.4, -78.7),
            "Washington": (47.4, -120.7), "West Virginia": (38.6, -80.6),
            "Wisconsin": (43.8, -88.8), "Wyoming": (43.1, -107.6),
            "District of Columbia": (38.9, -77.0),
        }
        # Aggregate by state for map display
        map_df = geo_df.groupby("REGION").agg(
            NET_SALES=("NET_SALES", "sum"),
            ORDERS=("ORDER_ID", "nunique"),
        ).reset_index()
        map_df["LAT"] = map_df["REGION"].map(
            lambda s: US_STATE_COORDS.get(s, (None, None))[0]
        )
        map_df["LON"] = map_df["REGION"].map(
            lambda s: US_STATE_COORDS.get(s, (None, None))[1]
        )
        map_df = map_df.dropna(subset=["LAT", "LON"])
        if not map_df.empty:
            # Normalize size for st.map (min 10, max 80)
            max_sales = map_df["NET_SALES"].max()
            min_size, max_size = 10, 80
            if max_sales > 0:
                map_df["size"] = (
                    min_size + (map_df["NET_SALES"] / max_sales)
                    * (max_size - min_size)
                )
            else:
                map_df["size"] = min_size
            map_df = map_df.rename(columns={
                "LAT": "latitude", "LON": "longitude",
            })
            st.map(map_df[["latitude", "longitude"]])
        else:
            st.info("No geographic data to map.")
    else:
        st.info("No geographic data.")

# --- Footer ---
st.divider()
if not df_target.empty:
    last_order_time = df_target["CREATED_AT"].max()
    st.caption(f"Last Order: {last_order_time} | Data cached for 5 minutes")
