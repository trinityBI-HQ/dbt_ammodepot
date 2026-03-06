"""Inventory — Stock levels, vendor analysis, and open POs.

Replaces: INVENTORY REDSHIFT (Power BI — 10 views, #4)
Source: AD_ANALYTICS.GOLD.F_INVENTORYVIEW, F_POS, D_PRODUCT, D_VENDOR
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

st.title("INVENTORY")

today = date.today()


# --- Sales period computation (UI rendered inside Inventory tab) ---
def _compute_sales_period():
    """Compute sales_start/sales_end/n_days from session state values."""
    period = st.session_state.get("inv_period", "YTD")
    custom = st.session_state.get("inv_custom_toggle", False)

    if custom:
        sel_year = st.session_state.get("inv_custom_year", today.year)
        sel_month_name = st.session_state.get("inv_custom_month", "All")
        months_list = [
            "All", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        if sel_month_name != "All":
            month_num = months_list.index(sel_month_name)
            start = date(sel_year, month_num, 1)
            if month_num == 12:
                end = date(sel_year, 12, 31)
            else:
                end = date(sel_year, month_num + 1, 1) - timedelta(days=1)
        else:
            start = date(sel_year, 1, 1)
            end = date(sel_year, 12, 31)
        if end > today:
            end = today
    elif period == "YESTERDAY":
        start = today - timedelta(days=1)
        end = today - timedelta(days=1)
    elif period == "7 DAYS":
        start = today - timedelta(days=7)
        end = today
    elif period == "MTD":
        start = today.replace(day=1)
        end = today
    else:  # YTD
        start = today.replace(month=1, day=1)
        end = today

    days = max((end - start).days, 1)
    return start, end, days


sales_start, sales_end, n_days = _compute_sales_period()


# --- Data loading ---
@st.cache_data(ttl=600)
def load_inventory() -> pd.DataFrame:
    sql = """
        select
            i.PART_NUMBER as SKU,
            i.QTY_AVAILABLE,
            i.QTY_NOT_AVAILABLE,
            i.QTY_ON_ORDER,
            i.PART_COST,
            i.EXTENDED_COST,
            p."Attribute Set" as CATEGORY,
            p."Caliber" as CALIBER,
            p."Projectile" as PROJECTILE,
            p."Manufacturer" as MANUFACTURER,
            p."Product Name" as PRODUCT_NAME
        from F_INVENTORYVIEW i
        left join D_PRODUCT p on i.PART_NUMBER = p.SKU
    """
    return run_query(sql)


@st.cache_data(ttl=600)
def load_units_sold(start_date: date, end_date: date) -> pd.DataFrame:
    """Units sold and cost per SKU for the selected period."""
    sql = f"""
        select
            TESTSKU as SKU,
            STORE_ID,
            sum(coalesce(PART_QTY_SOLD, QTY_ORDERED)) as UNITS_SOLD,
            sum(ROW_TOTAL) as NET_SALES,
            sum(COST) as COST_OF_GOODS
        from F_SALES
        where CREATED_AT::date between '{start_date}' and '{end_date}'
          and STATUS in ('COMPLETE', 'PROCESSING')
        group by TESTSKU, STORE_ID
    """
    return run_query(sql)


@st.cache_data(ttl=600)
def load_daily_units_sold(start_date: date, end_date: date) -> pd.DataFrame:
    """Daily total units sold for Units Sold/Period chart."""
    sql = f"""
        select
            CREATED_AT::date as SALE_DATE,
            STORE_ID,
            sum(coalesce(PART_QTY_SOLD, QTY_ORDERED)) as UNITS_SOLD
        from F_SALES
        where CREATED_AT::date between '{start_date}' and '{end_date}'
          and STATUS in ('COMPLETE', 'PROCESSING')
        group by CREATED_AT::date, STORE_ID
        order by SALE_DATE
    """
    return run_query(sql)


@st.cache_data(ttl=3600)
def load_store_names() -> pd.DataFrame:
    return run_query("select STORE_ID, NAME from D_STORE where IS_ACTIVE = true")


@st.cache_data(ttl=600)
def load_pos_data() -> pd.DataFrame:
    sql = """
        select
            f.PURCHASE_ORDER_ID,
            f.PART_NUMBER as SKU,
            f.VENDOR_ID,
            v.VENDOR_NAME,
            f.QTY,
            f.UNIT_COST,
            f.TOTAL_COST,
            f.DATERECEIVED,
            f.PO_CREATED_AT,
            f.PO_ISSUED_AT,
            f.SCHEDULED_FULFILLMENT_DATE,
            f.QUANTITY_FULFILLED,
            f.QUANTITY_TO_FULFILL,
            f.PRECISE_LEADTIME,
            f.DATE_EXPECTED,
            p."Caliber" as CALIBER,
            p."Attribute Set" as CATEGORY
        from F_POS f
        left join D_VENDOR v on f.VENDOR_ID = v.VENDOR_ID
        left join D_PRODUCT p on f.PART_NUMBER = p.SKU
    """
    return run_query(sql)


# --- Load all data ---
inv_df = load_inventory()
sold_df = load_units_sold(sales_start, sales_end)
daily_sold_df = load_daily_units_sold(sales_start, sales_end)
pos_df = load_pos_data()
store_df = load_store_names()

# --- Store filter (rendered later, logic here for data filtering) ---
store_names = store_df["NAME"].tolist() if not store_df.empty else []
# Store selection uses session state so UI can render after charts
for name in store_names:
    key = f"inv_store_{name}"
    if key not in st.session_state:
        st.session_state[key] = True

selected_store_ids = []
for name in store_names:
    if st.session_state.get(f"inv_store_{name}", True):
        sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
        selected_store_ids.append(sid)

if selected_store_ids and not sold_df.empty:
    sold_df = sold_df[sold_df["STORE_ID"].isin(selected_store_ids)]
if selected_store_ids and not daily_sold_df.empty:
    daily_sold_df = daily_sold_df[
        daily_sold_df["STORE_ID"].isin(selected_store_ids)
    ]

# Aggregate sold_df by SKU (after store filtering)
sold_agg = sold_df.groupby("SKU").agg(
    UNITS_SOLD=("UNITS_SOLD", "sum"),
    NET_SALES=("NET_SALES", "sum"),
    COST_OF_GOODS=("COST_OF_GOODS", "sum"),
).reset_index() if not sold_df.empty else pd.DataFrame(
    columns=["SKU", "UNITS_SOLD", "NET_SALES", "COST_OF_GOODS"]
)

# Aggregate daily sold by date (after store filtering)
if not daily_sold_df.empty:
    daily_agg = daily_sold_df.groupby("SALE_DATE")["UNITS_SOLD"].sum().reset_index()
else:
    daily_agg = pd.DataFrame(columns=["SALE_DATE", "UNITS_SOLD"])

# --- Sub-pages via tabs ---
tab_inv, tab_vendor, tab_open_po = st.tabs(["Inventory", "Vendor Analysis", "Open POs"])

# =============================================================================
# TAB 1: INVENTORY OVERVIEW
# =============================================================================
with tab_inv:
    # Filters
    filter_cols = st.columns([3, 3, 3, 3])
    with filter_cols[0]:
        categories = sorted(inv_df["CATEGORY"].dropna().unique().tolist()) if not inv_df.empty else []
        sel_categories = st.multiselect("Category", categories, key="inv_cat")
    with filter_cols[1]:
        calibers = sorted(inv_df["CALIBER"].dropna().unique().tolist()) if not inv_df.empty else []
        sel_calibers = st.multiselect("Caliber", calibers, key="inv_cal")
    with filter_cols[2]:
        projectiles = sorted(inv_df["PROJECTILE"].dropna().unique().tolist()) if not inv_df.empty else []
        sel_projectiles = st.multiselect("Projectile", projectiles, key="inv_proj")

    df = inv_df.copy()
    if sel_categories:
        df = df[df["CATEGORY"].isin(sel_categories)]
    if sel_calibers:
        df = df[df["CALIBER"].isin(sel_calibers)]
    if sel_projectiles:
        df = df[df["PROJECTILE"].isin(sel_projectiles)]

    # Merge units sold for DoS calculation
    df = df.merge(sold_agg, on="SKU", how="left")
    df["UNITS_SOLD"] = df["UNITS_SOLD"].fillna(0)
    df["NET_SALES"] = df["NET_SALES"].fillna(0)
    df["COST_OF_GOODS"] = df["COST_OF_GOODS"].fillna(0)
    df["DAILY_AVG"] = df["UNITS_SOLD"] / n_days
    df["DAYS_OF_SUPPLY"] = df.apply(
        lambda r: r["QTY_AVAILABLE"] / r["DAILY_AVG"] if r["DAILY_AVG"] > 0 else None, axis=1
    )

    # Derived columns for PBI match
    df["PCT_MARGIN"] = df.apply(
        lambda r: ((r["NET_SALES"] - r["COST_OF_GOODS"]) / r["NET_SALES"] * 100)
        if r["NET_SALES"] > 0 else 0, axis=1,
    )
    df["DOS_PLUS_ON_ORDER"] = df.apply(
        lambda r: (r["QTY_AVAILABLE"] + r["QTY_ON_ORDER"]) / r["DAILY_AVG"]
        if r["DAILY_AVG"] > 0 else None, axis=1,
    )
    df["COST_ON_ORDER"] = df["QTY_ON_ORDER"] * df["PART_COST"]

    # KPIs
    total_qty = df["QTY_AVAILABLE"].sum() if not df.empty else 0
    total_cost = df["EXTENDED_COST"].sum() if not df.empty else 0
    total_on_order = df["QTY_ON_ORDER"].sum() if not df.empty else 0
    total_units_sold = df["UNITS_SOLD"].sum() if not df.empty else 0
    avg_dos = (total_qty / (total_units_sold / n_days)) if total_units_sold > 0 else 0

    st.divider()
    kpi_cols = st.columns(5)
    with kpi_cols[0]:
        st.metric("Qty on Hand", f"{total_qty:,.0f}")
    with kpi_cols[1]:
        st.metric("Cost on Hand", f"${total_cost:,.0f}")
    with kpi_cols[2]:
        st.metric("Units Sold", f"{total_units_sold:,.0f}")
    with kpi_cols[3]:
        st.metric("Qty on Order", f"{total_on_order:,.0f}")
    with kpi_cols[4]:
        st.metric("Days of Supply", f"{avg_dos:,.0f}" if avg_dos else "N/A")

    st.divider()

    # Metric toggles for inventory bar charts (matches PBI left sidebar)
    # Two dimensions: QUANTITY/COST + On Hand/On Order/Total
    toggle_cols = st.columns([3, 5])
    with toggle_cols[0]:
        inv_unit = st.radio(
            "Unit", ["QUANTITY", "COST"],
            index=0, horizontal=True, key="inv_unit",
        )
    with toggle_cols[1]:
        inv_stock = st.radio(
            "Stock", ["On Hand", "On Order", "Total"],
            index=0, horizontal=True, key="inv_stock",
        )

    # Derive column based on both toggles
    if not df.empty:
        df["QTY_TOTAL"] = df["QTY_AVAILABLE"] + df["QTY_ON_ORDER"]
        df["COST_ON_ORDER"] = df["QTY_ON_ORDER"] * df["PART_COST"]
        df["COST_TOTAL"] = df["EXTENDED_COST"] + df["COST_ON_ORDER"]

    INV_COL_MAP = {
        ("QUANTITY", "On Hand"): "QTY_AVAILABLE",
        ("QUANTITY", "On Order"): "QTY_ON_ORDER",
        ("QUANTITY", "Total"): "QTY_TOTAL",
        ("COST", "On Hand"): "EXTENDED_COST",
        ("COST", "On Order"): "COST_ON_ORDER",
        ("COST", "Total"): "COST_TOTAL",
    }
    inv_col = INV_COL_MAP[(inv_unit, inv_stock)]
    is_cost = inv_unit == "COST"

    # Charts
    chart_cols = st.columns(3)
    with chart_cols[0]:
        st.subheader("Inventory Per Category")
        if not df.empty:
            cat_df = df.groupby("CATEGORY")[inv_col].sum().sort_values(ascending=True).tail(8).reset_index()
            if not cat_df.empty:
                # Add value labels
                text_vals = [f"${v:,.2f}" if is_cost else f"{v:,.0f}" for v in cat_df[inv_col]]
                fig = go.Figure(go.Bar(
                    x=cat_df[inv_col].tolist(),
                    y=cat_df["CATEGORY"].tolist(),
                    orientation="h",
                    marker_color="#5B9BD5",
                    text=text_vals,
                    textposition="outside",
                ))
                fig.update_layout(height=300, margin=dict(l=0, r=100, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="", visible=False)
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    with chart_cols[1]:
        st.subheader("Inventory Per Caliber")
        if not df.empty:
            cal_df = df.groupby("CALIBER")[inv_col].sum().sort_values(ascending=True).tail(8).reset_index()
            if not cal_df.empty:
                text_vals = [f"${v:,.2f}" if is_cost else f"{v:,.0f}" for v in cal_df[inv_col]]
                fig = go.Figure(go.Bar(
                    x=cal_df[inv_col].tolist(),
                    y=cal_df["CALIBER"].tolist(),
                    orientation="h",
                    marker_color="#5B9BD5",
                    text=text_vals,
                    textposition="outside",
                ))
                fig.update_layout(height=300, margin=dict(l=0, r=100, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="", visible=False)
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    with chart_cols[2]:
        st.subheader("Inventory Per Projectile")
        if not df.empty:
            proj_df = df.groupby("PROJECTILE")[inv_col].sum().sort_values(ascending=True).tail(8).reset_index()
            if not proj_df.empty:
                text_vals = [f"${v:,.2f}" if is_cost else f"{v:,.0f}" for v in proj_df[inv_col]]
                fig = go.Figure(go.Bar(
                    x=proj_df[inv_col].tolist(),
                    y=proj_df["PROJECTILE"].tolist(),
                    orientation="h",
                    marker_color="#5B9BD5",
                    text=text_vals,
                    textposition="outside",
                ))
                fig.update_layout(height=300, margin=dict(l=0, r=100, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="", visible=False)
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # --- Sales Filters (period for units sold / analytical view) ---
    st.markdown("**Sales Filters**")
    sf_row = st.columns([2, 2, 2, 2, 3])
    with sf_row[0]:
        st.radio(
            "Period",
            ["YESTERDAY", "7 DAYS", "MTD", "YTD"],
            index=["YESTERDAY", "7 DAYS", "MTD", "YTD"].index(
                st.session_state.get("inv_period", "YTD")
            ),
            horizontal=True,
            label_visibility="collapsed",
            key="inv_period",
        )
    with sf_row[4]:
        st.checkbox("Custom Filters", value=False, key="inv_custom_toggle")

    if st.session_state.get("inv_custom_toggle", False):
        custom_cols = st.columns([2, 2, 2, 2])
        years = list(range(today.year, 2018, -1))
        months_list = [
            "All", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        with custom_cols[0]:
            st.selectbox("Year", years, index=0, key="inv_custom_year")
        with custom_cols[1]:
            st.selectbox("Month", months_list, index=0, key="inv_custom_month")
        with custom_cols[2]:
            st.selectbox(
                "Week", ["All", "W1", "W2", "W3", "W4"],
                index=0, key="inv_custom_week",
            )
        day_options = [
            "All", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday", "Sunday",
        ]
        with custom_cols[3]:
            st.selectbox("Day of Week", day_options, index=0, key="inv_custom_day")

    # Analytical View toggle (matches PBI right panel)
    st.markdown("**Analytical View**")
    anal_view = st.radio(
        "View",
        ["OVERVIEW", "LOW STOCK", "OVERSTOCK"],
        index=0,
        horizontal=True,
        key="inv_analytical_view",
        label_visibility="collapsed",
    )

    if not df.empty:
        # Compute Total % on Hand
        total_all_qty = df["QTY_AVAILABLE"].sum()
        df["PCT_ON_HAND"] = (
            (df["QTY_AVAILABLE"] / total_all_qty * 100)
            if total_all_qty > 0 else 0
        )

        if anal_view == "OVERVIEW":
            st.subheader("Overview Inventory")
            table_df = df[[
                "SKU", "QTY_AVAILABLE", "PCT_ON_HAND",
                "UNITS_SOLD", "DAYS_OF_SUPPLY", "DAILY_AVG",
                "EXTENDED_COST", "NET_SALES", "PCT_MARGIN",
            ]].copy()
            table_df = table_df.sort_values(
                "DAILY_AVG", ascending=False,
            ).head(50)
            table_df.columns = [
                "Manufacturer SKU", "Qty on Hand",
                "Total % on Hand", "Units Sold in Period",
                "DoS", "Daily Average Units Sold",
                "Cost on Hand", "Net Sales ($)", "% Margin",
            ]
            st.dataframe(
                table_df.style.format({
                    "Qty on Hand": "{:,.0f}",
                    "Total % on Hand": "{:.2f}%",
                    "Units Sold in Period": "{:,.0f}",
                    "DoS": "{:,.0f}",
                    "Daily Average Units Sold": "{:,.0f}",
                    "Cost on Hand": "${:,.0f}",
                    "Net Sales ($)": "${:,.0f}",
                    "% Margin": "{:.2f}%",
                }).hide(axis="index"),
                use_container_width=True,
            )

        elif anal_view == "LOW STOCK":
            st.subheader("Lowstock")
            # Low stock = items with low DoS relative to demand
            low_df = df.copy()
            low_df = low_df.sort_values(
                "DAYS_OF_SUPPLY", ascending=True, na_position="first",
            ).head(50)
            table_df = low_df[[
                "SKU", "QTY_AVAILABLE", "PCT_ON_HAND",
                "UNITS_SOLD", "DAYS_OF_SUPPLY", "DAILY_AVG",
                "NET_SALES",
            ]].copy()
            table_df.columns = [
                "Manufacturer SKU", "Qty On Hand", "Total %",
                "Units Sold", "Days of Stock",
                "Daily Average Units Sold", "Net Sales ($)",
            ]
            st.dataframe(
                table_df.style.format({
                    "Qty On Hand": "{:,.0f}",
                    "Total %": "{:.2f}%",
                    "Units Sold": "{:,.0f}",
                    "Days of Stock": "{:,.0f}",
                    "Daily Average Units Sold": "{:,.0f}",
                    "Net Sales ($)": "${:,.0f}",
                }).hide(axis="index"),
                use_container_width=True,
            )

        else:  # OVERSTOCK
            st.subheader("Overstock")
            # Overstock = items with high DoS (excess inventory)
            over_df = df.copy()
            over_df = over_df.sort_values(
                "DAYS_OF_SUPPLY", ascending=False, na_position="last",
            ).head(50)
            table_df = over_df[[
                "SKU", "QTY_AVAILABLE", "PCT_ON_HAND",
                "UNITS_SOLD", "DAYS_OF_SUPPLY", "DAILY_AVG",
                "NET_SALES", "DOS_PLUS_ON_ORDER",
                "QTY_ON_ORDER", "EXTENDED_COST",
            ]].copy()
            table_df.columns = [
                "Manufacturer SKU", "Qty On Hand", "Total%",
                "Units Sold", "DoS", "Daily Average Units Sold",
                "Net Sales ($)", "DOS + On Order",
                "Qty On Order", "Cost on Hand",
            ]
            st.dataframe(
                table_df.style.format({
                    "Qty On Hand": "{:,.0f}",
                    "Total%": "{:.2f}%",
                    "Units Sold": "{:,.0f}",
                    "DoS": "{:,.0f}",
                    "Daily Average Units Sold": "{:,.0f}",
                    "Net Sales ($)": "${:,.0f}",
                    "DOS + On Order": "{:,.0f}",
                    "Qty On Order": "{:,.0f}",
                    "Cost on Hand": "${:,.0f}",
                }).hide(axis="index"),
                use_container_width=True,
            )
    else:
        st.info("No inventory data.")

    st.divider()

    # Units Sold/Period chart (matches PBI bottom chart)
    st.subheader("Units Sold/Period")
    if not daily_agg.empty:
        daily_agg_sorted = daily_agg.sort_values("SALE_DATE")
        dates = [str(d) for d in daily_agg_sorted["SALE_DATE"].tolist()]
        units = daily_agg_sorted["UNITS_SOLD"].tolist()
        avg_val = sum(units) / len(units) if units else 0

        fig = go.Figure()
        fig.add_trace(go.Bar(
            x=dates,
            y=units,
            name="Units Sold",
            marker_color="#5B9BD5",
            text=[f"{v:,.0f}" for v in units],
            textposition="outside",
        ))
        fig.add_trace(go.Scatter(
            x=dates,
            y=[avg_val] * len(dates),
            name="Daily Average",
            mode="lines",
            line=dict(color="#00d4aa", dash="dot", width=2),
        ))
        fig.update_layout(
            height=350,
            margin=dict(l=40, r=20, t=10, b=40),
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="left", x=0),
            xaxis=dict(type="category"),
        )
        fig.update_xaxes(title="")
        fig.update_yaxes(title="")
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No sales data for the selected period.")

    # --- Store filter UI (rendered at bottom, matches PBI) ---
    st.divider()
    if store_names:
        st.markdown("**STORE**")
        store_ui_cols = st.columns(len(store_names))
        for i, name in enumerate(store_names):
            with store_ui_cols[i]:
                st.checkbox(
                    name, value=True,
                    key=f"inv_store_{name}",
                )

# =============================================================================
# TAB 2: VENDOR ANALYSIS
# =============================================================================
with tab_vendor:
    if not pos_df.empty:
        # Filter to received items only
        received_df = pos_df[pos_df["DATERECEIVED"].notna()].copy()

        # Vendor filter
        vendors = sorted(received_df["VENDOR_NAME"].dropna().unique().tolist())
        sel_vendor = st.multiselect("Vendor", vendors, key="va_vendor")
        if sel_vendor:
            received_df = received_df[received_df["VENDOR_NAME"].isin(sel_vendor)]

        st.divider()

        # Charts row
        chart_cols = st.columns(2)

        with chart_cols[0]:
            st.subheader("Qty Received / Month")
            if not received_df.empty:
                received_df["MONTH"] = pd.to_datetime(received_df["DATERECEIVED"]).dt.to_period("M").astype(str)
                monthly_qty = received_df.groupby("MONTH")["QTY"].sum().reset_index().tail(12)
                fig = go.Figure(go.Bar(
                    x=monthly_qty["MONTH"].tolist(),
                    y=monthly_qty["QTY"].tolist(),
                    marker_color="#00d4aa",
                ))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

        with chart_cols[1]:
            st.subheader("Avg Unit Cost / Month")
            if not received_df.empty:
                monthly_cost = received_df.groupby("MONTH")["UNIT_COST"].mean().reset_index().tail(12)
                fig = go.Figure(go.Scatter(
                    x=monthly_cost["MONTH"].tolist(),
                    y=monthly_cost["UNIT_COST"].tolist(),
                    mode="lines+markers",
                    line=dict(color="#00d4aa"),
                ))
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

        st.divider()

        # Breakdown tables
        table_cols = st.columns(3)

        with table_cols[0]:
            st.subheader("By Vendor")
            vendor_agg = received_df.groupby("VENDOR_NAME").agg(
                QTY=("QTY", "sum"),
                TOTAL_COST=("TOTAL_COST", "sum"),
                POS=("PURCHASE_ORDER_ID", "nunique"),
            ).reset_index().sort_values("QTY", ascending=False).head(15)
            vendor_agg["AVG_COST"] = (vendor_agg["TOTAL_COST"] / vendor_agg["QTY"]).round(2)
            st.dataframe(
                vendor_agg.style.format({
                    "QTY": "{:,.0f}",
                    "TOTAL_COST": "${:,.2f}",
                    "AVG_COST": "${:,.2f}",
                }).hide(axis="index"),
                use_container_width=True,
            )

        with table_cols[1]:
            st.subheader("By Caliber")
            cal_agg = received_df.groupby("CALIBER").agg(
                QTY=("QTY", "sum"),
                TOTAL_COST=("TOTAL_COST", "sum"),
            ).reset_index().sort_values("QTY", ascending=False).head(15)
            st.dataframe(
                cal_agg.style.format({
                    "QTY": "{:,.0f}",
                    "TOTAL_COST": "${:,.2f}",
                }).hide(axis="index"),
                use_container_width=True,
            )

        with table_cols[2]:
            st.subheader("By Part SKU")
            sku_agg = received_df.groupby("SKU").agg(
                QTY=("QTY", "sum"),
                TOTAL_COST=("TOTAL_COST", "sum"),
                UNIT_COST=("UNIT_COST", "mean"),
            ).reset_index().sort_values("QTY", ascending=False).head(15)
            st.dataframe(
                sku_agg.style.format({
                    "QTY": "{:,.0f}",
                    "TOTAL_COST": "${:,.2f}",
                    "UNIT_COST": "${:,.4f}",
                }).hide(axis="index"),
                use_container_width=True,
            )
    else:
        st.info("No purchase order data available.")

# =============================================================================
# TAB 3: OPEN POs
# =============================================================================
with tab_open_po:
    if not pos_df.empty:
        # Open POs = quantity_to_fulfill > quantity_fulfilled
        open_df = pos_df[
            (pos_df["QUANTITY_TO_FULFILL"].notna())
            & (pos_df["QUANTITY_FULFILLED"].notna())
            & (pos_df["QUANTITY_TO_FULFILL"] > pos_df["QUANTITY_FULFILLED"])
        ].copy()

        if not open_df.empty:
            open_df["QTY_REMAINING"] = open_df["QUANTITY_TO_FULFILL"] - open_df["QUANTITY_FULFILLED"]
            open_df["IS_OVERDUE"] = open_df["SCHEDULED_FULFILLMENT_DATE"].apply(
                lambda x: pd.to_datetime(x).date() < today if pd.notna(x) else False
            )

            # KPIs
            total_open = open_df["PURCHASE_ORDER_ID"].nunique()
            total_remaining = open_df["QTY_REMAINING"].sum()
            overdue_count = open_df[open_df["IS_OVERDUE"]]["PURCHASE_ORDER_ID"].nunique()

            st.divider()
            kpi_cols = st.columns(4)
            with kpi_cols[0]:
                st.metric("Open POs", f"{total_open:,}")
            with kpi_cols[1]:
                st.metric("Qty Remaining", f"{total_remaining:,.0f}")
            with kpi_cols[2]:
                st.metric("Overdue POs", f"{overdue_count:,}")
            with kpi_cols[3]:
                avg_lt = open_df["PRECISE_LEADTIME"].mean()
                st.metric("Avg Lead Time (days)", f"{avg_lt:,.0f}" if pd.notna(avg_lt) else "N/A")

            st.divider()

            # Open PO table
            st.subheader("Open Purchase Orders")
            po_table = open_df.groupby(["PURCHASE_ORDER_ID", "VENDOR_NAME"]).agg(
                QTY_REMAINING=("QTY_REMAINING", "sum"),
                TOTAL_COST=("TOTAL_COST", "sum"),
                SCHEDULED=("SCHEDULED_FULFILLMENT_DATE", "max"),
                DATE_EXPECTED=("DATE_EXPECTED", "max"),
                LEAD_TIME=("PRECISE_LEADTIME", "mean"),
                IS_OVERDUE=("IS_OVERDUE", "max"),
            ).reset_index().sort_values("SCHEDULED", ascending=True)

            po_table["STATUS"] = po_table["IS_OVERDUE"].apply(lambda x: "OVERDUE" if x else "On Track")
            display_cols = [
                "PURCHASE_ORDER_ID", "VENDOR_NAME", "QTY_REMAINING",
                "TOTAL_COST", "SCHEDULED", "DATE_EXPECTED",
                "LEAD_TIME", "STATUS",
            ]
            st.dataframe(
                po_table[display_cols].style.format({
                    "QTY_REMAINING": "{:,.0f}",
                    "TOTAL_COST": "${:,.2f}",
                    "LEAD_TIME": "{:,.0f}",
                }).hide(axis="index"),
                use_container_width=True,
            )

            st.divider()

            # Breakdown tables
            table_cols = st.columns(2)
            with table_cols[0]:
                st.subheader("Open POs / By Vendor")
                v_agg = open_df.groupby("VENDOR_NAME").agg(
                    QTY_REMAINING=("QTY_REMAINING", "sum"),
                    POS=("PURCHASE_ORDER_ID", "nunique"),
                    LEAD_TIME=("PRECISE_LEADTIME", "mean"),
                ).reset_index().sort_values("QTY_REMAINING", ascending=False)
                st.dataframe(
                    v_agg.style.format({
                        "QTY_REMAINING": "{:,.0f}",
                        "LEAD_TIME": "{:,.0f}",
                    }).hide(axis="index"),
                    use_container_width=True,
                )

            with table_cols[1]:
                st.subheader("Open POs / By SKU")
                s_agg = open_df.groupby("SKU").agg(
                    QTY_REMAINING=("QTY_REMAINING", "sum"),
                    LEAD_TIME=("PRECISE_LEADTIME", "mean"),
                ).reset_index().sort_values("QTY_REMAINING", ascending=False).head(20)
                st.dataframe(
                    s_agg.style.format({
                        "QTY_REMAINING": "{:,.0f}",
                        "LEAD_TIME": "{:,.0f}",
                    }).hide(axis="index"),
                    use_container_width=True,
                )
        else:
            st.info("No open purchase orders found.")
    else:
        st.info("No purchase order data available.")

# --- Footer ---
st.divider()
st.caption("Data cached for 10 minutes")
