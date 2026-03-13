"""Inventory — Stock levels, vendor analysis, and open POs.

Replaces: INVENTORY REDSHIFT (Power BI — 10 views, #4)
Source: AD_ANALYTICS.GOLD.F_INVENTORYVIEW, F_POS, D_PRODUCT, D_VENDOR
"""

import base64
import pathlib
import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query
from utils.chart_theme import apply_theme, secondary_axis_style, dark_dataframe

_logo_path = pathlib.Path(__file__).parents[1] / "AmmoDepot.png"
_logo_b64 = base64.b64encode(_logo_path.read_bytes()).decode()
if hasattr(st, "logo"):
    st.logo(str(_logo_path))

# Remove default padding to use full screen width
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
    f'<h1 style="margin:0;">INVENTORY</h1>'
    f'</div>',
    unsafe_allow_html=True,
)

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
            f.RECEIPT_ITEM_ID,
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
            f.PO_FIRST_SHIPMENT_DATE,
            f.SCHEDULED_FULFILLMENT_DATE,
            f.QUANTITY_FULFILLED,
            f.QUANTITY_TO_FULFILL,
            f.PRECISE_LEADTIME,
            f.DATE_EXPECTED,
            p.CALIBER,
            p.CATEGORY
        from F_POS f
        left join D_VENDOR v on f.VENDOR_ID = v.VENDOR_ID
        left join (
            select SKU,
                   "Caliber" as CALIBER,
                   "Attribute Set" as CATEGORY,
                   row_number() over (partition by SKU order by SKU) as rn
            from D_PRODUCT
        ) p on f.PART_NUMBER = p.SKU and p.rn = 1
        where f.LOCATION_GROUP_ID = 8
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

    # Helper: PBI-style horizontal bar chart (dark background matching KPI cards)
    def _render_inv_hbar(labels, values, is_cost_fmt):
        """Render PBI-style horizontal bars with dark background."""
        if not labels or not values:
            st.info("No data.")
            return
        total = sum(values)
        max_val = max(values) if values else 1
        html_rows = []
        for lbl, val in zip(labels, values):
            pct = (val / total * 100) if total else 0
            val_str = f"${val:,.0f}" if is_cost_fmt else f"{int(val):,}"
            bar_pct = (val / max_val * 100) if max_val else 0
            html_rows.append(
                f'<div style="margin-bottom:6px;">'
                f'<div style="font-size:12px; color:#ccc; margin-bottom:2px;'
                f' white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">'
                f'{lbl}&nbsp;&nbsp;<span style="color:#aaa;">{val_str} ({pct:.0f}%)</span></div>'
                f'<div style="background:#5B9BD5; height:16px; width:{bar_pct:.1f}%; border-radius:2px;"></div>'
                f'</div>'
            )
        st.markdown(
            f'<div style="background:#1E1E1E; border-radius:8px; padding:12px 16px;">'
            f'{"".join(html_rows)}</div>',
            unsafe_allow_html=True,
        )

    # Charts
    chart_cols = st.columns(3)
    with chart_cols[0]:
        st.subheader("Inventory Per Category")
        if not df.empty:
            cat_df = df.groupby("CATEGORY")[inv_col].sum().sort_values(ascending=False).head(15).reset_index()
            if not cat_df.empty:
                _render_inv_hbar(cat_df["CATEGORY"].tolist(), cat_df[inv_col].tolist(), is_cost)

    with chart_cols[1]:
        st.subheader("Inventory Per Caliber")
        if not df.empty:
            cal_df = df.groupby("CALIBER")[inv_col].sum().sort_values(ascending=False).head(15).reset_index()
            if not cal_df.empty:
                _render_inv_hbar(cal_df["CALIBER"].tolist(), cal_df[inv_col].tolist(), is_cost)

    with chart_cols[2]:
        st.subheader("Inventory Per Projectile")
        if not df.empty:
            proj_df = df.groupby("PROJECTILE")[inv_col].sum().sort_values(ascending=False).head(15).reset_index()
            if not proj_df.empty:
                _render_inv_hbar(proj_df["PROJECTILE"].tolist(), proj_df[inv_col].tolist(), is_cost)

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
            dark_dataframe(table_df, fmt={
                "Qty on Hand": "{:,.0f}",
                "Total % on Hand": "{:.2f}%",
                "Units Sold in Period": "{:,.0f}",
                "DoS": "{:,.0f}",
                "Daily Average Units Sold": "{:,.0f}",
                "Cost on Hand": "${:,.0f}",
                "Net Sales ($)": "${:,.0f}",
                "% Margin": "{:.2f}%",
            })

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
            dark_dataframe(table_df, fmt={
                "Qty On Hand": "{:,.0f}",
                "Total %": "{:.2f}%",
                "Units Sold": "{:,.0f}",
                "Days of Stock": "{:,.0f}",
                "Daily Average Units Sold": "{:,.0f}",
                "Net Sales ($)": "${:,.0f}",
            })

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
            dark_dataframe(table_df, fmt={
                "Qty On Hand": "{:,.0f}",
                "Total%": "{:.2f}%",
                "Units Sold": "{:,.0f}",
                "DoS": "{:,.0f}",
                "Daily Average Units Sold": "{:,.0f}",
                "Net Sales ($)": "${:,.0f}",
                "DOS + On Order": "{:,.0f}",
                "Qty On Order": "{:,.0f}",
                "Cost on Hand": "${:,.0f}",
            })
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
        apply_theme(fig, height=350, margin=dict(l=40, r=20, t=10, b=40))
        fig.update_layout(xaxis=dict(type="category"))
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
                    name,
                    key=f"inv_store_{name}",
                )

# =============================================================================
# TAB 2: VENDOR ANALYSIS
# =============================================================================
with tab_vendor:
    if not pos_df.empty:
        # --- Receipt Filters ---
        st.markdown("**RECEIPT FILTERS**")
        rcpt_periods = ["L. 30 Days", "L. 90 Days", "L. 180 Days", "L. 365 Days"]
        rf_row = st.columns([2, 2, 2, 2, 3])
        with rf_row[0]:
            rcpt_period = st.radio(
                "Receipt Period", rcpt_periods,
                index=2, horizontal=True,
                label_visibility="collapsed",
                key="va_rcpt_period",
            )
        with rf_row[4]:
            va_show_custom = st.checkbox(
                "Custom Filters", value=False, key="va_custom_toggle",
            )

        # Compute receipt date range
        rcpt_days_map = {
            "L. 30 Days": 30, "L. 90 Days": 90,
            "L. 180 Days": 180, "L. 365 Days": 365,
        }
        rcpt_lookback = rcpt_days_map[rcpt_period]
        rcpt_start = today - timedelta(days=rcpt_lookback)
        rcpt_end = today

        if va_show_custom:
            va_custom_cols = st.columns([2, 2, 2, 2])
            years = list(range(today.year, 2018, -1))
            months_list = [
                "All", "January", "February", "March", "April", "May",
                "June", "July", "August", "September", "October",
                "November", "December",
            ]
            with va_custom_cols[0]:
                va_year = st.selectbox("Year", years, index=0, key="va_year")
            with va_custom_cols[1]:
                va_month = st.selectbox(
                    "Month", months_list, index=0, key="va_month",
                )
            with va_custom_cols[2]:
                va_week = st.selectbox(
                    "Week", ["All", "W1", "W2", "W3", "W4"],
                    index=0, key="va_week",
                )
            day_options = [
                "All", "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday", "Sunday",
            ]
            with va_custom_cols[3]:
                va_day = st.selectbox(
                    "Day of Week", day_options, index=0, key="va_day",
                )
            # Override receipt period from custom filters
            if va_month != "All":
                month_num = months_list.index(va_month)
                rcpt_start = date(va_year, month_num, 1)
                if month_num == 12:
                    rcpt_end = date(va_year, 12, 31)
                else:
                    rcpt_end = date(va_year, month_num + 1, 1) - timedelta(days=1)
            else:
                rcpt_start = date(va_year, 1, 1)
                rcpt_end = date(va_year, 12, 31)
            if rcpt_end > today:
                rcpt_end = today

        # Filter to received items within receipt period
        # PBI filters: Attribute Set = Ammunition, QTY != 0
        received_df = pos_df[
            pos_df["DATERECEIVED"].notna()
            & (pos_df["CATEGORY"] == "Ammunition")
            & (pos_df["QTY"] != 0)
        ].copy()
        received_df["RCPT_DATE"] = pd.to_datetime(received_df["DATERECEIVED"]).dt.date
        received_df = received_df[
            (received_df["RCPT_DATE"] >= rcpt_start)
            & (received_df["RCPT_DATE"] <= rcpt_end)
        ]

        # Vendor filter
        vendors = sorted(received_df["VENDOR_NAME"].dropna().unique().tolist())
        sel_vendor = st.multiselect("Vendor", vendors, key="va_vendor")
        if sel_vendor:
            received_df = received_df[
                received_df["VENDOR_NAME"].isin(sel_vendor)
            ]

        st.divider()

        # --- QTY AND COST PER RECEIPTS (dual-axis chart) ---
        chart_row = st.columns([3, 2])
        with chart_row[0]:
            st.subheader("QTY AND COST PER RECEIPTS")
            # Chart uses ALL received data (back to 2019), filtered to Ammunition only
            all_received = pos_df[
                pos_df["DATERECEIVED"].notna()
                & (pos_df["CATEGORY"] == "Ammunition")
                & (pos_df["QTY"] != 0)
            ].copy()
            if not all_received.empty:
                all_received["MONTH_KEY"] = (
                    pd.to_datetime(all_received["DATERECEIVED"])
                    .dt.to_period("M").astype(str)
                )
                monthly = all_received.groupby("MONTH_KEY").agg(
                    QTY=("QTY", "sum"),
                    AVG_COST=("UNIT_COST", "mean"),
                ).reset_index().sort_values(
                    "MONTH_KEY", ascending=False,
                )

                # Use numeric positions for x to avoid duplicate labels
                x_pos = list(range(len(monthly)))
                qty_vals = monthly["QTY"].tolist()
                cost_vals = monthly["AVG_COST"].tolist()

                # Tick labels: "Nov", "Dec", "Jan<br>2026"
                tick_labels = []
                prev_year = None
                for mk in monthly["MONTH_KEY"]:
                    dt = pd.Timestamp(mk)
                    mon = dt.strftime("%b")
                    yr = dt.year
                    if prev_year is not None and yr != prev_year:
                        tick_labels.append(f"{mon}<br>{yr}")
                    else:
                        tick_labels.append(mon)
                    prev_year = yr

                fig = go.Figure()
                fig.add_trace(go.Bar(
                    x=x_pos, y=qty_vals,
                    name="QTY",
                    marker_color="#5B9BD5",
                    text=[f"{v:,.0f}" for v in qty_vals],
                    textposition="outside",
                    yaxis="y",
                ))
                fig.add_trace(go.Scatter(
                    x=x_pos, y=cost_vals,
                    name="Avg. Cost",
                    mode="lines+markers+text",
                    line=dict(color="#E8B84B", dash="dot", width=2),
                    marker=dict(color="#E8B84B", size=6),
                    text=[f"${v:,.2f}" for v in cost_vals],
                    textposition="top center",
                    textfont=dict(size=10),
                    yaxis="y2",
                ))
                # Show ~10 most recent months initially, scroll for rest
                n_months = len(x_pos)
                visible_end = min(10, n_months) - 1
                apply_theme(fig, height=400, margin=dict(l=50, r=50, t=10, b=40))
                fig.update_layout(
                    yaxis=dict(title="", side="left"),
                    yaxis2=dict(
                        title="", side="right",
                        overlaying="y", showgrid=False,
                        **secondary_axis_style(),
                    ),
                    xaxis=dict(
                        tickmode="array",
                        tickvals=x_pos,
                        ticktext=tick_labels,
                        range=[-0.5, visible_end + 0.5],
                        rangeslider=dict(visible=True, thickness=0.05),
                    ),
                )
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.info("No receipt data available.")

        # --- INDIVIDUAL POS table ---
        with chart_row[1]:
            st.subheader("INDIVIDUAL POS")
            if not received_df.empty:
                po_detail = received_df.groupby("PURCHASE_ORDER_ID").agg(
                    CREATED=("PO_CREATED_AT", "min"),
                    F_DELIVER=("RCPT_DATE", "min"),
                    L_DELIVER=("RCPT_DATE", "max"),
                    FILLED=("QTY", "sum"),
                    TOTAL=("QUANTITY_TO_FULFILL", "max"),
                    LT=("PRECISE_LEADTIME", "mean"),
                    EXPECTED=("DATE_EXPECTED", "max"),
                    DELIVERS=("RCPT_DATE", "nunique"),
                ).reset_index().sort_values(
                    "PURCHASE_ORDER_ID", ascending=False,
                ).head(30)

                po_detail["CREATED"] = pd.to_datetime(
                    po_detail["CREATED"]
                ).dt.strftime("%m/%d/%Y")
                po_detail["F_DELIVER"] = pd.to_datetime(
                    po_detail["F_DELIVER"].astype(str)
                ).dt.strftime("%m/%d/%Y")
                po_detail["L_DELIVER"] = pd.to_datetime(
                    po_detail["L_DELIVER"].astype(str)
                ).dt.strftime("%m/%d/%Y")
                po_detail["EXPECTED"] = pd.to_datetime(
                    po_detail["EXPECTED"]
                ).dt.strftime("%m/%d/%Y")
                po_detail["PCT"] = po_detail.apply(
                    lambda r: (r["FILLED"] / r["TOTAL"] * 100)
                    if r["TOTAL"] and r["TOTAL"] > 0 else 0,
                    axis=1,
                )
                po_detail["LT_EXPECTED"] = po_detail["LT"]

                display_po = po_detail[[
                    "PURCHASE_ORDER_ID", "CREATED", "F_DELIVER",
                    "L_DELIVER", "FILLED", "TOTAL", "PCT",
                    "LT", "LT_EXPECTED", "EXPECTED", "DELIVERS",
                ]].copy()
                display_po.columns = [
                    "POID", "Created", "F. Deliver", "L. Deliver",
                    "FILLED", "TOTAL", "%",
                    "LT", "LT Expected", "Expected", "Delivers",
                ]
                # POID should display as integer (no decimals, no commas)
                display_po["POID"] = display_po["POID"].astype(int)
                dark_dataframe(display_po, fmt={
                    "POID": "{:d}",
                    "FILLED": "{:,.0f}",
                    "TOTAL": "{:,.0f}",
                    "%": "{:.2f}%",
                    "LT": "{:,.0f}",
                    "LT Expected": "{:,.0f}",
                    "Delivers": "{:,.0f}",
                }, height=400)
            else:
                st.info("No PO data for the selected period.")

        st.divider()

        # --- Breakdown tables (VENDOR, CALIBER, PART SKU) ---
        def _build_breakdown(grp_df, group_col, group_label):
            """Build PBI-matching breakdown with totals row."""
            agg = grp_df.groupby(group_col).agg(
                QTY=("QTY", "sum"),
                TOTAL_COST=("TOTAL_COST", "sum"),
                DELIVERS=("PURCHASE_ORDER_ID", "nunique"),
                LT=("PRECISE_LEADTIME", "mean"),
            ).reset_index().sort_values("QTY", ascending=False)

            agg["AVG_COST"] = (agg["TOTAL_COST"] / agg["QTY"]).round(2)
            agg["W_AVG_COST"] = (agg["TOTAL_COST"] / agg["QTY"]).round(2)

            # Totals row
            totals = pd.DataFrame([{
                group_col: "Total",
                "QTY": agg["QTY"].sum(),
                "AVG_COST": (
                    agg["TOTAL_COST"].sum() / agg["QTY"].sum()
                    if agg["QTY"].sum() > 0 else 0
                ),
                "DELIVERS": agg["DELIVERS"].sum(),
                "LT": agg["LT"].mean(),
                "W_AVG_COST": (
                    agg["TOTAL_COST"].sum() / agg["QTY"].sum()
                    if agg["QTY"].sum() > 0 else 0
                ),
                "TOTAL_COST": agg["TOTAL_COST"].sum(),
            }])
            agg = pd.concat([agg.head(15), totals], ignore_index=True)

            table = agg[[
                group_col, "QTY", "AVG_COST", "DELIVERS",
                "LT", "W_AVG_COST", "TOTAL_COST",
            ]].copy()
            table.columns = [
                group_label, "QTY", "Avg. Cost", "Delivers",
                "LT", "W. Avg. Cost", "Total Cost",
            ]
            return table

        table_cols = st.columns(3)
        if not received_df.empty:
            with table_cols[0]:
                st.subheader("VENDOR")
                vt = _build_breakdown(received_df, "VENDOR_NAME", "VENDOR")
                _bd_fmt = {
                    "QTY": "{:,.0f}", "Avg. Cost": "${:,.2f}",
                    "Delivers": "{:,.0f}", "LT": "{:,.0f}",
                    "W. Avg. Cost": "${:,.2f}", "Total Cost": "${:,.0f}",
                }
                dark_dataframe(vt, fmt=_bd_fmt)

            with table_cols[1]:
                st.subheader("CALIBER")
                ct = _build_breakdown(received_df, "CALIBER", "CALIBER")
                dark_dataframe(ct, fmt=_bd_fmt)

            with table_cols[2]:
                st.subheader("PART SKU")
                pt = _build_breakdown(received_df, "SKU", "PART SKU")
                dark_dataframe(pt, fmt=_bd_fmt)
        else:
            st.info("No receipt data for the selected period.")
    else:
        st.info("No purchase order data available.")

# =============================================================================
# TAB 3: OPEN POs
# =============================================================================
with tab_open_po:
    if not pos_df.empty:
        # Open POs = not yet received, Ammunition only, QTY > 0
        open_df = pos_df[
            pos_df["DATERECEIVED"].isna()
            & (pos_df["CATEGORY"] == "Ammunition")
            & (pos_df["QTY"] != 0)
        ].copy()

        if not open_df.empty:
            open_df["DATE_EXPECTED_DT"] = pd.to_datetime(open_df["DATE_EXPECTED"])
            open_df["SCHED_DT"] = pd.to_datetime(open_df["SCHEDULED_FULFILLMENT_DATE"])
            open_df["CREATED_DT"] = pd.to_datetime(open_df["PO_CREATED_AT"])

            # --- Row 1: Sales Filters + Date Projection | Purchase Order Status ---
            top_row = st.columns([1, 1])

            with top_row[0]:
                # Sales Filters (period buttons + custom)
                filt_cols = st.columns([3, 2])
                with filt_cols[0]:
                    st.markdown("**SALES FILTERS**")
                    op_period = st.radio(
                        "Period", ["YESTERDAY", "7 DAYS", "MTD", "YTD"],
                        index=3, horizontal=True, key="op_period",
                        label_visibility="collapsed",
                    )
                with filt_cols[1]:
                    op_custom = st.checkbox("Custom Filters", key="op_custom")

                if op_custom:
                    cust_cols = st.columns(4)
                    years = list(range(today.year, 2018, -1))
                    month_names = [
                        "All", "January", "February", "March", "April",
                        "May", "June", "July", "August", "September",
                        "October", "November", "December",
                    ]
                    with cust_cols[0]:
                        op_year = st.selectbox("Year", years, key="op_year")
                    with cust_cols[1]:
                        op_month = st.selectbox("Month", month_names, key="op_month")
                    with cust_cols[2]:
                        op_week = st.selectbox(
                            "Week", ["All", "W1", "W2", "W3", "W4"], key="op_week",
                        )
                    with cust_cols[3]:
                        op_day = st.selectbox(
                            "Day of Week",
                            ["All", "Monday", "Tuesday", "Wednesday",
                             "Thursday", "Friday", "Saturday", "Sunday"],
                            key="op_day",
                        )

                # Date Projection slider
                st.markdown("**DATE PROJECTION**")
                min_exp = open_df["DATE_EXPECTED_DT"].dropna().min()
                max_exp = open_df["DATE_EXPECTED_DT"].dropna().max()
                if pd.notna(min_exp) and pd.notna(max_exp):
                    proj_range = st.date_input(
                        "Projection range",
                        value=(min_exp.date(), max_exp.date()),
                        min_value=min_exp.date(),
                        max_value=max_exp.date(),
                        key="op_proj_range",
                        label_visibility="collapsed",
                    )
                    if isinstance(proj_range, tuple) and len(proj_range) == 2:
                        proj_start, proj_end = proj_range
                    else:
                        proj_start, proj_end = min_exp.date(), max_exp.date()
                else:
                    proj_start, proj_end = today, today

            with top_row[1]:
                # Purchase Order Status toggle
                st.markdown("**PURCHASE ORDER STATUS**")
                # Determine overdue per PO
                po_status = open_df.groupby("PURCHASE_ORDER_ID").agg(
                    MAX_EXPECTED=("DATE_EXPECTED_DT", "max"),
                ).reset_index()
                po_status["IS_OVERDUE"] = po_status["MAX_EXPECTED"].apply(
                    lambda x: x.date() < today if pd.notna(x) else False
                )
                overdue_poids = set(
                    po_status[po_status["IS_OVERDUE"]]["PURCHASE_ORDER_ID"]
                )
                regular_poids = set(
                    po_status[~po_status["IS_OVERDUE"]]["PURCHASE_ORDER_ID"]
                )

                status_filter = st.radio(
                    "Status", ["Select all", "OVERDUE", "REGULAR"],
                    index=0, horizontal=True, key="op_status",
                    label_visibility="collapsed",
                )

                if status_filter == "OVERDUE":
                    visible_poids = overdue_poids
                elif status_filter == "REGULAR":
                    visible_poids = regular_poids
                else:
                    visible_poids = overdue_poids | regular_poids

                # Filter open_df by status and date projection
                filtered_df = open_df[
                    open_df["PURCHASE_ORDER_ID"].isin(visible_poids)
                ].copy()
                filtered_df = filtered_df[
                    filtered_df["DATE_EXPECTED_DT"].apply(
                        lambda x: proj_start <= x.date() <= proj_end
                        if pd.notna(x) else True
                    )
                ]

                # TOTAL POS table
                st.markdown("**TOTAL POS**")
                if not filtered_df.empty:
                    po_agg = filtered_df.groupby("PURCHASE_ORDER_ID").agg(
                        EXPECTED=("DATE_EXPECTED_DT", "max"),
                        ADJUSTED=("SCHED_DT", "max"),
                        CREATED=("CREATED_DT", "max"),
                        L_DELIVER=("DATERECEIVED", "max"),
                        QTY=("QTY", "sum"),
                        FILLED=("QUANTITY_FULFILLED", "sum"),
                        TOTAL=("QUANTITY_TO_FULFILL", "sum"),
                        LT_EXPECTED=("PRECISE_LEADTIME", "mean"),
                    ).reset_index().sort_values(
                        "PURCHASE_ORDER_ID", ascending=False,
                    )
                    po_agg["PCT"] = po_agg.apply(
                        lambda r: (r["FILLED"] / r["TOTAL"] * 100)
                        if r["TOTAL"] and r["TOTAL"] > 0 else 0,
                        axis=1,
                    )
                    po_agg["POID"] = po_agg["PURCHASE_ORDER_ID"].astype(int)
                    po_agg["EXPECTED"] = pd.to_datetime(
                        po_agg["EXPECTED"]
                    ).dt.strftime("%m/%d/%Y")
                    po_agg["ADJUSTED"] = pd.to_datetime(
                        po_agg["ADJUSTED"]
                    ).dt.strftime("%m/%d/%Y")
                    po_agg["CREATED"] = pd.to_datetime(
                        po_agg["CREATED"]
                    ).dt.strftime("%m/%d/%Y")
                    po_agg["L_DELIVER"] = pd.to_datetime(
                        po_agg["L_DELIVER"]
                    ).dt.strftime("%m/%d/%Y")

                    disp_po = po_agg[[
                        "POID", "EXPECTED", "ADJUSTED", "CREATED",
                        "L_DELIVER", "QTY", "FILLED", "TOTAL",
                        "LT_EXPECTED", "PCT",
                    ]].copy()
                    disp_po.columns = [
                        "POID", "Expected", "Adjusted", "Created",
                        "L. Deliver", "QTY", "FILLED", "TOTAL",
                        "LT EXPECTED", "%",
                    ]
                    dark_dataframe(disp_po, fmt={
                        "POID": "{:d}",
                        "QTY": "{:,.0f}",
                        "FILLED": "{:,.0f}",
                        "TOTAL": "{:,.0f}",
                        "LT EXPECTED": "{:,.0f}",
                        "%": "{:.2f}%",
                    }, height=300)
                else:
                    st.info("No POs match the current filters.")

            st.divider()

            # --- Row 2: Inventory Projections ---
            st.subheader("INVENTORY PROJECTIONS")

            # Build projection: current on-hand - daily sales + incoming POs
            if not filtered_df.empty and not inv_df.empty:
                # Current on-hand (Ammunition only)
                inv_ammo = inv_df[inv_df["CATEGORY"] == "Ammunition"]
                current_on_hand = inv_ammo["QTY_AVAILABLE"].sum()

                # Daily sales rate from selected period
                total_sold = sold_agg["UNITS_SOLD"].sum() if not sold_agg.empty else 0
                daily_rate = total_sold / n_days if n_days > 0 else 0

                # Incoming POs by expected date
                incoming = filtered_df[
                    filtered_df["DATE_EXPECTED_DT"].notna()
                ].groupby(
                    filtered_df["DATE_EXPECTED_DT"].dt.date
                )["QTY"].sum().to_dict()

                # Build daily projection from today to projection end
                proj_dates = []
                proj_values = []
                proj_incoming = []
                running = float(current_on_hand)
                d = today
                while d <= proj_end:
                    # Add incoming POs for this date
                    arrived = float(incoming.get(d, 0))
                    running += arrived
                    # Subtract daily sales
                    running -= daily_rate
                    proj_dates.append(d)
                    proj_values.append(max(running, 0))
                    proj_incoming.append(arrived)
                    d += timedelta(days=1)

                if proj_dates:
                    fig_proj = go.Figure()

                    # Projected inventory line
                    fig_proj.add_trace(go.Scatter(
                        x=proj_dates, y=proj_values,
                        name="Projected Inventory",
                        mode="lines",
                        line=dict(color="#5B9BD5", width=2),
                        fill="tozeroy",
                        fillcolor="rgba(91,155,213,0.15)",
                    ))

                    # Incoming PO markers (only on days with arrivals)
                    arrival_dates = [d for d, v in zip(proj_dates, proj_incoming) if v > 0]
                    arrival_vals = [v for v in proj_incoming if v > 0]
                    arrival_inv = [
                        proj_values[i]
                        for i, v in enumerate(proj_incoming) if v > 0
                    ]
                    if arrival_dates:
                        fig_proj.add_trace(go.Scatter(
                            x=arrival_dates, y=arrival_inv,
                            name="PO Arrival",
                            mode="markers+text",
                            marker=dict(
                                color="#2ECC71", size=10, symbol="triangle-up",
                            ),
                            text=[f"+{v:,.0f}" for v in arrival_vals],
                            textposition="top center",
                            textfont=dict(size=9, color="#2ECC71"),
                        ))

                    # Zero-stock threshold line
                    fig_proj.add_hline(
                        y=0, line_dash="dash",
                        line_color="red", opacity=0.5,
                        annotation_text="Out of Stock",
                        annotation_position="bottom right",
                    )

                    # Stockout date annotation
                    stockout_date = None
                    for i, v in enumerate(proj_values):
                        if v <= 0:
                            stockout_date = proj_dates[i]
                            break

                    if stockout_date:
                        fig_proj.add_vline(
                            x=stockout_date, line_dash="dot",
                            line_color="red", opacity=0.6,
                        )
                        fig_proj.add_annotation(
                            x=stockout_date, y=max(proj_values) * 0.8,
                            text=f"Stockout: {stockout_date:%m/%d/%Y}",
                            showarrow=True, arrowhead=2,
                            font=dict(color="red", size=11),
                        )

                    apply_theme(fig_proj, height=350, margin=dict(l=50, r=30, t=30, b=40))
                    fig_proj.update_layout(
                        yaxis=dict(title="Units"),
                        xaxis=dict(title=""),
                        annotations=list(fig_proj.layout.annotations or ()) + [
                            dict(
                                x=0.01, y=0.98, xref="paper", yref="paper",
                                text=(
                                    f"On Hand: {current_on_hand:,.0f}"
                                    f"  |  Daily Sales: {daily_rate:,.0f}"
                                    f"  |  Incoming: {sum(proj_incoming):,.0f}"
                                ),
                                showarrow=False,
                                font=dict(size=11),
                                bgcolor="rgba(0,0,0,0.6)",
                                bordercolor="rgba(255,255,255,0.2)",
                                borderwidth=1,
                            ),
                        ],
                    )

                    st.plotly_chart(fig_proj, use_container_width=True)

                    # Summary metrics row
                    m_cols = st.columns(5)
                    with m_cols[0]:
                        st.metric("Current On Hand", f"{current_on_hand:,.0f}")
                    with m_cols[1]:
                        st.metric("Daily Avg Sales", f"{daily_rate:,.0f}")
                    with m_cols[2]:
                        dos = int(current_on_hand / daily_rate) if daily_rate > 0 else 0
                        st.metric("Days of Supply", f"{dos:,}")
                    with m_cols[3]:
                        st.metric("Open PO Units", f"{sum(proj_incoming):,.0f}")
                    with m_cols[4]:
                        if stockout_date:
                            days_to = (stockout_date - today).days
                            st.metric("Stockout In", f"{days_to} days")
                        else:
                            st.metric("Stockout In", "N/A (covered)")
                else:
                    st.info("No projection data available.")
            else:
                st.info("No open PO or inventory data for projection.")

            st.divider()

            # --- Row 3: Breakdown tables (VENDOR, CALIBER, PART SKU) ---
            def _build_open_breakdown(grp_df, group_col, group_label):
                """Build PBI-matching breakdown for open POs."""
                agg = grp_df.groupby(group_col).agg(
                    QTY=("QTY", "sum"),
                    TOTAL_COST=("TOTAL_COST", "sum"),
                    LT_EXPECTED=("PRECISE_LEADTIME", "mean"),
                ).reset_index().sort_values("QTY", ascending=False)

                agg["AVG_COST"] = (agg["TOTAL_COST"] / agg["QTY"]).round(2)
                agg["W_AVG_COST"] = (agg["TOTAL_COST"] / agg["QTY"]).round(2)

                totals = pd.DataFrame([{
                    group_col: "Total",
                    "QTY": agg["QTY"].sum(),
                    "AVG_COST": (
                        agg["TOTAL_COST"].sum() / agg["QTY"].sum()
                        if agg["QTY"].sum() > 0 else 0
                    ),
                    "LT_EXPECTED": agg["LT_EXPECTED"].mean(),
                    "W_AVG_COST": (
                        agg["TOTAL_COST"].sum() / agg["QTY"].sum()
                        if agg["QTY"].sum() > 0 else 0
                    ),
                    "TOTAL_COST": agg["TOTAL_COST"].sum(),
                }])
                agg = pd.concat([agg.head(15), totals], ignore_index=True)

                table = agg[[
                    group_col, "QTY", "AVG_COST", "LT_EXPECTED",
                    "W_AVG_COST", "TOTAL_COST",
                ]].copy()
                table.columns = [
                    group_label, "QTY", "Avg. Cost", "LT EXPECTED",
                    "W. Avg. Cost", "Total Cost",
                ]
                return table

            if not filtered_df.empty:
                tbl_cols = st.columns(3)
                with tbl_cols[0]:
                    st.subheader("VENDOR")
                    vt = _build_open_breakdown(
                        filtered_df, "VENDOR_NAME", "VENDOR",
                    )
                    _op_fmt = {
                        "QTY": "{:,.0f}", "Avg. Cost": "${:,.2f}",
                        "LT EXPECTED": "{:,.0f}",
                        "W. Avg. Cost": "${:,.2f}", "Total Cost": "${:,.0f}",
                    }
                    dark_dataframe(vt, fmt=_op_fmt)
                with tbl_cols[1]:
                    st.subheader("CALIBER")
                    ct = _build_open_breakdown(
                        filtered_df, "CALIBER", "CALIBER",
                    )
                    dark_dataframe(ct, fmt=_op_fmt)
                with tbl_cols[2]:
                    st.subheader("PART SKU")
                    pt = _build_open_breakdown(
                        filtered_df, "SKU", "PART SKU",
                    )
                    dark_dataframe(pt, fmt=_op_fmt)
            else:
                st.info("No open PO data for the selected filters.")
        else:
            st.info("No open purchase orders found.")
    else:
        st.info("No purchase order data available.")

# --- Footer ---
st.divider()
st.caption("Data cached for 10 minutes")
