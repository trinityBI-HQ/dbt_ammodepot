"""Today / Yesterday — Real-time sales dashboard.

Replaces: SALES OVERVIEW FASTER (Power BI — 1,188 views, #1 most used)
Source: AD_ANALYTICS.GOLD.F_SALES
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

# --- Page config ---
st.title("SALES OVERVIEW: TODAY / YESTERDAY")

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
            CREATED_AT,
            TIMEDATE,
            extract(HOUR from TIMEDATE) as HOUR_NUM,
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
            extract(HOUR from TIMEDATE) as HOUR_NUM,
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
            extract(HOUR from TIMEDATE) as HOUR_NUM,
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
            fig.add_trace(go.Scatter(
                x=hourly_target["HOUR_LABEL"].tolist(),
                y=hourly_target["VALUE"].tolist(),
                name=period, marker_color="#00d4aa",
                mode="lines+markers",
                marker=dict(size=6),
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
                   sum(f.ROW_TOTAL)::float as NET_SALES,
                   sum(f.COST)::float as COST,
                   count(distinct f.INCREMENT_ID) as ORDERS,
                   sum(coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED))::float as UNITS
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT = '{target_date}'
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
            fig = go.Figure(go.Bar(
                x=cat_df[val_col].tolist(),
                y=cat_df["CATEGORY"].tolist(),
                orientation="h", marker_color="#00d4aa",
            ))
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
            fig = go.Figure(go.Bar(
                x=vendor_agg["VALUE"].tolist(),
                y=vendor_agg["VENDOR"].tolist(),
                orientation="h", marker_color="#00d4aa",
            ))
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
                   sum(f.ROW_TOTAL)::float as NET_SALES,
                   sum(f.COST)::float as COST,
                   count(distinct f.INCREMENT_ID) as ORDERS,
                   sum(coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED))::float as UNITS
            from F_SALES f
            join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
            where f.CREATED_AT = '{target_date}'
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
            fig = go.Figure(go.Bar(
                x=mfr_df[val_col].tolist(),
                y=mfr_df["MANUFACTURER"].tolist(),
                orientation="h", marker_color="#00d4aa",
            ))
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
                fig.update_layout(
                    mapbox=dict(
                        style="carto-darkmatter",
                        center=dict(lat=38, lon=-97),
                        zoom=3,
                    ),
                    height=350,
                    margin=dict(l=0, r=0, t=0, b=0),
                    showlegend=False,
                )
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No geographic data to map.")
    else:
        st.info("No geographic data.")

# --- Footer ---
st.divider()
if not df_target.empty:
    last_order_time = df_target["CREATED_AT"].max()
    st.caption(f"Last Order: {last_order_time} | Data cached for 5 minutes")
