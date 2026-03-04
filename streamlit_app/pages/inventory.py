"""Inventory — Stock levels, vendor analysis, and open POs.

Replaces: INVENTORY REDSHIFT (Power BI — 10 views, #4)
Source: AD_ANALYTICS.GOLD.F_INVENTORYVIEW, F_POS, D_PRODUCT, D_VENDOR
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import date, timedelta

from utils.db import run_query

st.title("INVENTORY")

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
def load_units_sold_30d() -> pd.DataFrame:
    """Units sold per SKU over last 30 days for Days of Supply calc."""
    sql = f"""
        select
            TESTSKU as SKU,
            sum(coalesce(PART_QTY_SOLD, QTY_ORDERED)) as UNITS_SOLD,
            sum(ROW_TOTAL) as NET_SALES
        from F_SALES
        where CREATED_AT::date >= dateadd(day, -30, current_date())
          and STATUS in ('complete', 'processing')
          and STATUS not in ('closed', 'canceled', 'holded', 'fraud')
        group by TESTSKU
    """
    return run_query(sql)


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
        left join D_PRODUCT p on f.SKU = p.SKU
    """
    return run_query(sql)


@st.cache_data(ttl=3600)
def load_store_names() -> pd.DataFrame:
    return run_query("select STORE_ID, NAME from D_STORE where IS_ACTIVE = true")


# --- Load all data ---
inv_df = load_inventory()
sold_df = load_units_sold_30d()
pos_df = load_pos_data()

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
    df = df.merge(sold_df, on="SKU", how="left")
    df["UNITS_SOLD"] = df["UNITS_SOLD"].fillna(0)
    df["NET_SALES"] = df["NET_SALES"].fillna(0)
    df["DAILY_AVG"] = df["UNITS_SOLD"] / 30
    df["DAYS_OF_SUPPLY"] = df.apply(
        lambda r: r["QTY_AVAILABLE"] / r["DAILY_AVG"] if r["DAILY_AVG"] > 0 else None, axis=1
    )

    # KPIs
    total_qty = df["QTY_AVAILABLE"].sum() if not df.empty else 0
    total_cost = df["EXTENDED_COST"].sum() if not df.empty else 0
    total_on_order = df["QTY_ON_ORDER"].sum() if not df.empty else 0
    total_units_sold = df["UNITS_SOLD"].sum() if not df.empty else 0
    avg_dos = (total_qty / (total_units_sold / 30)) if total_units_sold > 0 else 0

    st.divider()
    kpi_cols = st.columns(5)
    with kpi_cols[0]:
        st.metric("Qty on Hand", f"{total_qty:,.0f}")
    with kpi_cols[1]:
        st.metric("Cost on Hand", f"${total_cost:,.0f}")
    with kpi_cols[2]:
        st.metric("Units Sold (30d)", f"{total_units_sold:,.0f}")
    with kpi_cols[3]:
        st.metric("Qty on Order", f"{total_on_order:,.0f}")
    with kpi_cols[4]:
        st.metric("Days of Supply", f"{avg_dos:,.0f}" if avg_dos else "N/A")

    st.divider()

    # Charts
    chart_cols = st.columns(3)
    with chart_cols[0]:
        st.subheader("Qty on Hand / Category")
        if not df.empty:
            cat_df = df.groupby("CATEGORY")["QTY_AVAILABLE"].sum().sort_values(ascending=False).head(8).reset_index()
            if not cat_df.empty:
                fig = px.bar(cat_df, x="QTY_AVAILABLE", y="CATEGORY", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    with chart_cols[1]:
        st.subheader("Qty on Hand / Caliber")
        if not df.empty:
            cal_df = df.groupby("CALIBER")["QTY_AVAILABLE"].sum().sort_values(ascending=False).head(8).reset_index()
            if not cal_df.empty:
                fig = px.bar(cal_df, x="QTY_AVAILABLE", y="CALIBER", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    with chart_cols[2]:
        st.subheader("Qty on Hand / Projectile")
        if not df.empty:
            proj_df = df.groupby("PROJECTILE")["QTY_AVAILABLE"].sum().sort_values(ascending=False).head(8).reset_index()
            if not proj_df.empty:
                fig = px.bar(proj_df, x="QTY_AVAILABLE", y="PROJECTILE", orientation="h", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # Inventory overview table
    st.subheader("Inventory Overview")
    if not df.empty:
        total_all_qty = df["QTY_AVAILABLE"].sum()
        df["PCT_TOTAL"] = (df["QTY_AVAILABLE"] / total_all_qty * 100).round(2) if total_all_qty > 0 else 0
        table_df = df[["SKU", "QTY_AVAILABLE", "PCT_TOTAL", "UNITS_SOLD", "DAYS_OF_SUPPLY", "DAILY_AVG", "EXTENDED_COST", "NET_SALES"]].copy()
        table_df = table_df.sort_values("QTY_AVAILABLE", ascending=False).head(50)
        table_df.columns = ["SKU", "Qty on Hand", "% Total", "Units Sold (30d)", "Days of Supply", "Daily Avg", "Cost on Hand", "Net Sales (30d)"]
        st.dataframe(
            table_df.style.format({
                "Qty on Hand": "{:,.0f}",
                "% Total": "{:.2f}%",
                "Units Sold (30d)": "{:,.0f}",
                "Days of Supply": "{:,.0f}",
                "Daily Avg": "{:,.1f}",
                "Cost on Hand": "${:,.2f}",
                "Net Sales (30d)": "${:,.2f}",
            }),
            hide_index=True,
            use_container_width=True,
        )
    else:
        st.info("No inventory data.")

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
                monthly_qty = received_df.groupby("MONTH")["QTY"].sum().reset_index()
                monthly_qty = monthly_qty.tail(12)
                fig = px.bar(monthly_qty, x="MONTH", y="QTY", color_discrete_sequence=["#00d4aa"])
                fig.update_layout(height=300, margin=dict(l=0, r=0, t=10, b=0), showlegend=False)
                fig.update_xaxes(title="")
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)

        with chart_cols[1]:
            st.subheader("Avg Unit Cost / Month")
            if not received_df.empty:
                monthly_cost = received_df.groupby("MONTH")["UNIT_COST"].mean().reset_index()
                monthly_cost = monthly_cost.tail(12)
                fig = px.line(monthly_cost, x="MONTH", y="UNIT_COST", color_discrete_sequence=["#00d4aa"])
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
                }),
                hide_index=True,
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
                }),
                hide_index=True,
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
                }),
                hide_index=True,
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
            today = date.today()
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
            display_cols = ["PURCHASE_ORDER_ID", "VENDOR_NAME", "QTY_REMAINING", "TOTAL_COST", "SCHEDULED", "DATE_EXPECTED", "LEAD_TIME", "STATUS"]
            st.dataframe(
                po_table[display_cols].style.format({
                    "QTY_REMAINING": "{:,.0f}",
                    "TOTAL_COST": "${:,.2f}",
                    "LEAD_TIME": "{:,.0f}",
                }),
                hide_index=True,
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
                    }),
                    hide_index=True,
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
                    }),
                    hide_index=True,
                    use_container_width=True,
                )
        else:
            st.info("No open purchase orders found.")
    else:
        st.info("No purchase order data available.")

# --- Footer ---
st.divider()
st.caption("Data cached for 10 minutes")
