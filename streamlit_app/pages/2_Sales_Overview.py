"""Sales Overview — Historical sales dashboard with category pages.

Replaces: SALES OVERVIEW REDSHIFT (Power BI — 168 views, #2) + REALTIME
Source: AD_ANALYTICS.GOLD.F_SALES, D_PRODUCT, D_CUSTOMER, D_STORE
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

# Title placeholder — updated after category selection
_title_placeholder = st.empty()

# Statuses preselected by default (matches Power BI default filter)
DEFAULT_STATUSES = {"COMPLETE", "PROCESSING", "UNVERIFIED"}
FREE_SHIPPING_THRESHOLD = 140  # matches dbt var ammodepot_free_shipping_threshold


@st.cache_data(ttl=3600)
def load_order_statuses() -> list:
    df = run_query("select distinct upper(STATUS) as STATUS from F_SALES order by STATUS")
    return df["STATUS"].tolist() if not df.empty else []


all_statuses = load_order_statuses()
default_statuses = [s for s in all_statuses if s in DEFAULT_STATUSES]

# --- Category pages (mirrors Power BI 9-page structure) ---
CATEGORIES = [
    "Ammunition",
    "Guns",
    "Magazines",
    "Gun Parts",
    "Gear",
    "Optics",
    "Loading Components",
    "Survival",
]
# Display name overrides (DB value → UI label) and icons
CATEGORY_DISPLAY = {
    "Optics": "Optics/Sights",
    "Loading Components": "Load Comp",
    "Survival": "Prep & Survival",
}
CATEGORY_ICONS = {
    "Ammunition": "✖️",
    "Guns": "🔫",
    "Magazines": "🔋",
    "Gun Parts": "⚙️",
    "Gear": "🦺",
    "Optics": "🎯",
    "Loading Components": "🔧",
    "Survival": "⛑️",
}


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
            f.TIMEDATE,
            date_trunc('HOUR', f.TIMEDATE) as HOUR_BUCKET,
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
            f.PRODUCT_ID,
            f.TESTSKU as SKU,
            f.REGION,
            f.CITY,
            f.POSTCODE,
            coalesce(f.PART_QTY_SOLD, f.QTY_ORDERED)::int as UNITS,
            p."Attribute Set" as CATEGORY,
            p."Manufacturer" as MANUFACTURER,
            coalesce(p."DD Caliber", p."Caliber") as CALIBER,
            p."Projectile" as PROJECTILE,
            p."General Purpose" as GENERAL_PURPOSE,
            p."Manufacturer SKU" as MANUFACTURER_SKU,
            p."Product Name" as PRODUCT_NAME,
            p."DD Gun Action" as GUN_ACTION,
            p."Capacity" as CAPACITY,
            p."Material" as MATERIAL,
            p."DD Gun Parts" as GUN_PART,
            p."DD Color" as COLOR,
            p."Primary Category" as PRIMARY_CATEGORY,
            p."Categories" as CATEGORIES,
            p."Model" as MODEL,
            p.USE_TYPE_CATEGORY as GENERAL_PURPOSE_AMMO
        from F_SALES f
        left join D_PRODUCT p on f.PRODUCT_ID = p."Product ID"
        where f.CREATED_AT::date between '{start_date}' and '{end_date}'
          and f.STATUS in ({status_list})
    """
    return run_query(sql)


# --- Filters row 1: Period + Category + Order Status + Analytical View + Custom Filters ---
filter_cols = st.columns([2, 3, 3, 3, 3, 2])
with filter_cols[0]:
    period = st.radio("Period", ["TODAY", "MTD", "YTD"], horizontal=True)
with filter_cols[1]:
    category = st.selectbox(
        "Category", CATEGORIES,
        format_func=lambda c: f"{CATEGORY_ICONS.get(c, '')} {CATEGORY_DISPLAY.get(c, c)}",
    )
with filter_cols[2]:
    order_status = st.multiselect(
        "Order Status",
        all_statuses,
        default=default_statuses,
    )
with filter_cols[3]:
    analytical_view = st.radio("Analytical View", ["Hourly", "Bar Chart", "Heat Map"], horizontal=True)
with filter_cols[4]:
    metric_toggle = st.radio("Metric", ["$", "GP ($)", "Orders", "Units"], index=2, horizontal=True)
with filter_cols[5]:
    st.checkbox("Custom Filters", value=False, key="so_custom_toggle")

# --- Custom Filters row (Year / Month / Week / Day — matches PBI) ---
today = date.today()
custom_active = st.session_state.get("so_custom_toggle", False)

if custom_active:
    custom_cols = st.columns([2, 2, 2, 2])
    years = list(range(today.year, 2018, -1))
    months_list = [
        "All", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    with custom_cols[0]:
        st.selectbox("Year", years, index=0, key="so_custom_year")
    with custom_cols[1]:
        st.selectbox("Month", months_list, index=0, key="so_custom_month")
    with custom_cols[2]:
        st.selectbox(
            "Week", ["All", "W1", "W2", "W3", "W4"],
            index=0, key="so_custom_week",
        )
    day_options = [
        "All", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday", "Sunday",
    ]
    with custom_cols[3]:
        st.selectbox("Day of Week", day_options, index=0, key="so_custom_day")

# --- Dynamic title (rendered at top via placeholder) ---
_display_name = CATEGORY_DISPLAY.get(category, category)
_title_placeholder.markdown(
    f'<div style="display:flex;align-items:center;gap:12px;">'
    f'<img src="data:image/png;base64,{_logo_b64}" height="48">'
    f'<h1 style="margin:0;">SALES OVERVIEW: {_display_name.upper()}</h1>'
    f'</div>',
    unsafe_allow_html=True,
)

# Metric mapping: toggle value → (column, format, chart_label)
# Chart labels match PBI: "$", "G.P. ($)", "Orders", "Units"
METRIC_MAP = {
    "$": ("NET_SALES", "${:,.0f}", "Sales ($)"),
    "GP ($)": ("GP", "${:,.0f}", "G.P. ($)"),
    "Orders": ("ORDERS", "{:,.0f}", "Orders"),
    "Units": ("UNITS", "{:,.0f}", "Units"),
}
metric_col, metric_fmt, metric_label = METRIC_MAP[metric_toggle]

# --- Date logic ---
if custom_active:
    sel_year = st.session_state.get("so_custom_year", today.year)
    sel_month_name = st.session_state.get("so_custom_month", "All")
    months_list_idx = [
        "All", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    if sel_month_name != "All":
        month_num = months_list_idx.index(sel_month_name)
        start_date = date(sel_year, month_num, 1)
        if month_num == 12:
            end_date = date(sel_year, 12, 31)
        else:
            end_date = date(sel_year, month_num + 1, 1) - timedelta(days=1)
    else:
        start_date = date(sel_year, 1, 1)
        end_date = date(sel_year, 12, 31)
    if end_date > today:
        end_date = today
    # Compare to same period previous year
    compare_start = date(sel_year - 1, start_date.month, start_date.day)
    compare_end = date(sel_year - 1, end_date.month, min(end_date.day, 28))
    period_label = f"Custom ({start_date:%b %Y})" if sel_month_name != "All" else f"Custom ({sel_year})"
    compare_label = f"Prev Year ({sel_year - 1})"
elif period == "TODAY":
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

# --- Apply Custom Filters: Week / Day of Week ---
if custom_active and not df_target.empty:
    sel_week = st.session_state.get("so_custom_week", "All")
    sel_day = st.session_state.get("so_custom_day", "All")
    if sel_week != "All":
        week_num = int(sel_week.replace("W", ""))
        df_target = df_target.copy()
        df_target["_WEEK"] = ((pd.to_datetime(df_target["CREATED_AT"]).dt.day - 1) // 7) + 1
        df_target = df_target[df_target["_WEEK"] == week_num].drop(columns=["_WEEK"])
    if sel_day != "All":
        day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        day_num = day_names.index(sel_day)
        df_target = df_target[pd.to_datetime(df_target["CREATED_AT"]).dt.dayofweek == day_num]

# --- Storefront + Store filters (UI rendered at bottom, filtering here) ---
STOREFRONTS = ["Website", "GunBroker"]
# Initialize session state defaults (checked=True) on first run
for sf in STOREFRONTS:
    if f"so_sf_{sf}" not in st.session_state:
        st.session_state[f"so_sf_{sf}"] = True

store_names = store_df["NAME"].tolist() if not store_df.empty else []
for name in store_names:
    if f"so_store_{name}" not in st.session_state:
        st.session_state[f"so_store_{name}"] = True

# Apply storefront filter from session state
selected_storefronts = [sf for sf in STOREFRONTS if st.session_state.get(f"so_sf_{sf}", True)]
if selected_storefronts and not df_target.empty:
    df_target = df_target[df_target["STOREFRONT"].isin(selected_storefronts)]
    df_compare = df_compare[df_compare["STOREFRONT"].isin(selected_storefronts)]

# Apply store filter from session state
selected_store_ids = []
for name in store_names:
    if st.session_state.get(f"so_store_{name}", True):
        sid = store_df[store_df["NAME"] == name]["STORE_ID"].values[0]
        selected_store_ids.append(sid)
if selected_store_ids and not df_target.empty:
    df_target = df_target[df_target["STORE_ID"].isin(selected_store_ids)]
    df_compare = df_compare[df_compare["STORE_ID"].isin(selected_store_ids)]

# --- Category filter ---
if not df_target.empty:
    df_target = df_target[df_target["CATEGORY"] == category]
    df_compare = df_compare[df_compare["CATEGORY"] == category]

# --- Cross-filters (PBI-style click-to-filter) ---
_SO_XF_KEYS = ["so_xf_mfr", "so_xf_vendor", "so_xf_sku", "so_xf_cust"]

# Apply any pending chart-click filter BEFORE widgets render
_pending = st.session_state.pop("_so_xf_pending", None)
if _pending:
    _pkey, _pval = _pending
    st.session_state[_pkey] = _pval

for _k in _SO_XF_KEYS:
    if _k not in st.session_state:
        st.session_state[_k] = "All"


def _clear_so_xf():
    """Callback to clear all cross-filters (runs before widgets render)."""
    for _k in _SO_XF_KEYS:
        st.session_state[_k] = "All"


if not df_target.empty:
    _df_opts = df_target  # dropdown options from pre-cross-filter data
    xf_cols = st.columns([2, 2, 2, 2, 1])
    with xf_cols[0]:
        xf_mfr = st.selectbox(
            "Manufacturer",
            ["All"] + sorted(_df_opts["MANUFACTURER"].dropna().unique().tolist()),
            key="so_xf_mfr",
        )
    with xf_cols[1]:
        xf_vendor = st.selectbox(
            "Fulfilled By",
            ["All"] + sorted(_df_opts["VENDOR"].dropna().unique().tolist()),
            key="so_xf_vendor",
        )
    with xf_cols[2]:
        xf_sku = st.selectbox(
            "SKU",
            ["All"] + sorted(_df_opts["MANUFACTURER_SKU"].dropna().unique().tolist()),
            key="so_xf_sku",
        )
    with xf_cols[3]:
        xf_cust = st.selectbox(
            "Customer",
            ["All"] + sorted(_df_opts["CUSTOMER_EMAIL"].dropna().unique().tolist()),
            key="so_xf_cust",
        )
    with xf_cols[4]:
        st.markdown("<br>", unsafe_allow_html=True)
        st.button("Clear All", key="so_xf_clear", on_click=_clear_so_xf)

    # Apply cross-filters to target + compare
    _xf_pairs = [
        ("MANUFACTURER", xf_mfr), ("VENDOR", xf_vendor),
        ("MANUFACTURER_SKU", xf_sku), ("CUSTOMER_EMAIL", xf_cust),
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
            ("Manufacturer", "so_xf_mfr"), ("Fulfilled By", "so_xf_vendor"),
            ("SKU", "so_xf_sku"), ("Customer", "so_xf_cust"),
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


# --- KPI calculations ---
def calc_kpis(df: pd.DataFrame) -> dict:
    if df.empty:
        return {
            "net_sales": 0, "cost": 0, "gross_profit": 0,
            "orders": 0, "units": 0, "freight_rev": 0,
            "freight_cost": 0, "gp_after_var": 0, "free_ship_orders": 0,
        }
    net_sales = df["NET_SALES"].sum()
    cost = df["COST"].sum()
    gross_profit = net_sales - cost
    freight_rev = df["FREIGHT_REVENUE"].sum()
    freight_cost = df["FREIGHT_COST"].sum()
    # Free shipping orders: orders where order subtotal >= threshold
    order_totals = df.groupby("ORDER_ID")["NET_SALES"].sum()
    free_ship_orders = int((order_totals >= FREE_SHIPPING_THRESHOLD).sum())
    return {
        "net_sales": net_sales,
        "cost": cost,
        "gross_profit": gross_profit,
        "orders": df["ORDER_ID"].nunique(),
        "units": df["UNITS"].sum(),
        "freight_rev": freight_rev,
        "freight_cost": freight_cost,
        "gp_after_var": gross_profit - freight_cost,
        "free_ship_orders": free_ship_orders,
    }


kpi = calc_kpis(df_target)
kpi_prev = calc_kpis(df_compare)

margin = (kpi["gross_profit"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
avg_ticket = (kpi["net_sales"] / kpi["orders"]) if kpi["orders"] else 0
margin_prev = (kpi_prev["gross_profit"] / kpi_prev["net_sales"] * 100) if kpi_prev["net_sales"] else 0
avg_ticket_prev = (kpi_prev["net_sales"] / kpi_prev["orders"]) if kpi_prev["orders"] else 0
shipping_ns_pct = (kpi["freight_rev"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
shipping_ns_pct_prev = (kpi_prev["freight_rev"] / kpi_prev["net_sales"] * 100) if kpi_prev["net_sales"] else 0
contrib_margin = (kpi["gp_after_var"] / kpi["net_sales"] * 100) if kpi["net_sales"] else 0
contrib_margin_prev = (kpi_prev["gp_after_var"] / kpi_prev["net_sales"] * 100) if kpi_prev["net_sales"] else 0
n_days = max((end_date - start_date).days + 1, 1)
orders_per_day = kpi["orders"] / n_days


def pct_delta(current, previous):
    if previous and previous != 0:
        return f"{((current - previous) / abs(previous)) * 100:+.1f}%"
    return None


# --- KPI Row ---
st.divider()

kpi_cards = [
    {
        "icon": "&#x1F4B2;",
        "color": "#00B4D8",
        "title": "Net Sales ($)",
        "value": f"${kpi['net_sales']:,.0f}",
        "delta": pct_delta(kpi["net_sales"], kpi_prev["net_sales"]),
        "sub_label": "Avg Ticket",
        "sub_value": f"${avg_ticket:,.2f}",
        "prev_label": f"{compare_label}",
        "prev_lines": [
            f"Net Sales: <span class='kpi-sub-val'>${kpi_prev['net_sales']:,.0f}</span>",
            f"Avg Ticket: <span class='kpi-sub-val'>${avg_ticket_prev:,.2f}</span>",
        ],
    },
    {
        "icon": "&#x1F4C8;",
        "color": "#2DC653",
        "title": "Gross Profit ($)",
        "value": f"${kpi['gross_profit']:,.0f}",
        "delta": pct_delta(kpi["gross_profit"], kpi_prev["gross_profit"]),
        "sub_label": "Margin",
        "sub_value": f"{margin:.1f}%",
        "prev_label": f"{compare_label}",
        "prev_lines": [
            f"Gross Profit: <span class='kpi-sub-val'>${kpi_prev['gross_profit']:,.0f}</span>",
            f"Margin: <span class='kpi-sub-val'>{margin_prev:.1f}%</span>",
        ],
    },
    {
        "icon": "&#x1F6D2;",
        "color": "#00B4D8",
        "title": "Orders",
        "value": f"{kpi['orders']:,}",
        "delta": pct_delta(kpi["orders"], kpi_prev["orders"]),
        "badge": f"Free S. Orders: {kpi['free_ship_orders']}",
        "sub_label": "Orders/Day",
        "sub_value": f"{orders_per_day:.1f}",
        "prev_label": f"{compare_label}",
        "prev_lines": [
            f"Orders: <span class='kpi-sub-val'>{kpi_prev['orders']:,}</span>",
            f"Orders/Day: <span class='kpi-sub-val'>{kpi_prev['orders']}</span>",
        ],
    },
    {
        "icon": "&#x1F69A;",
        "color": "#2DC653",
        "title": "Shipping Revenue ($)",
        "value": f"${kpi['freight_rev']:,.0f}",
        "delta": pct_delta(kpi["freight_rev"], kpi_prev["freight_rev"]),
        "sub_label": "Shipping($) / NS($)",
        "sub_value": f"{shipping_ns_pct:.1f}%",
        "prev_label": f"{compare_label}",
        "prev_lines": [
            f"Shipping Revenue: <span class='kpi-sub-val'>${kpi_prev['freight_rev']:,.0f}</span>",
            f"Shipping/NS: <span class='kpi-sub-val'>{shipping_ns_pct_prev:.1f}%</span>",
        ],
    },
    {
        "icon": "&#x1F6E1;",
        "color": "#00B4D8",
        "title": "Gross Profit ($) After Variable Cost",
        "value": f"${kpi['gp_after_var']:,.0f}",
        "delta": pct_delta(kpi["gp_after_var"], kpi_prev["gp_after_var"]),
        "sub_label": "Contribution Margin",
        "sub_value": f"{contrib_margin:.1f}%",
        "prev_label": f"{compare_label}",
        "prev_lines": [
            f"Profitability: <span class='kpi-sub-val'>${kpi_prev['gp_after_var']:,.0f}</span>",
            f"Contribution Margin: <span class='kpi-sub-val'>{contrib_margin_prev:.1f}%</span>",
        ],
    },
]

# Build all KPI cards as a single HTML block (avoids per-column rendering issues)
_kpi_html_parts = []
for card in kpi_cards:
    delta = card["delta"]
    if delta and delta.startswith("+"):
        delta_class = "kpi-delta-pos"
    elif delta and delta.startswith("-"):
        delta_class = "kpi-delta-neg"
    else:
        delta_class = "kpi-delta-zero"
    delta_text = f"vs {compare_label}: {delta}" if delta else f"vs {compare_label}: --"

    badge_html = ""
    if card.get("badge"):
        badge_html = f'<span class="kpi-badge">{card["badge"]}</span>'

    prev_html = ""
    if card.get("prev_lines"):
        prev_html = (
            f'<div class="kpi-prev"><b>{card["prev_label"]}</b><br>'
            + "<br>".join(card["prev_lines"]) + "</div>"
        )

    _kpi_html_parts.append(
        f'<div class="kpi-card" style="border-left-color:{card["color"]};">'
        f'<div class="kpi-header">'
        f'<span class="kpi-icon">{card["icon"]}</span>'
        f'<span class="kpi-title">{card["title"]}</span>'
        f'{badge_html}'
        f'</div>'
        f'<div class="kpi-value">{card["value"]}</div>'
        f'<div class="kpi-delta {delta_class}">{delta_text}</div>'
        f'<div class="kpi-sub">'
        f'{card["sub_label"]}: <span class="kpi-sub-val">{card["sub_value"]}</span>'
        f'</div>'
        f'{prev_html}'
        f'</div>'
    )

_kpi_row_html = (
    '<style>'
    '.kpi-row{display:flex;gap:12px;margin-bottom:8px;}'
    '.kpi-card{background:#1E1E1E;border-radius:8px;padding:12px 16px;border-left:4px solid;flex:1;min-width:0;}'
    '.kpi-header{display:flex;align-items:center;gap:6px;margin-bottom:4px;}'
    '.kpi-icon{font-size:18px;}'
    '.kpi-title{font-size:12px;color:#AAAAAA;text-transform:uppercase;letter-spacing:0.5px;}'
    '.kpi-badge{font-size:10px;color:#00d4aa;background:#1a3a2a;padding:1px 6px;border-radius:4px;margin-left:auto;}'
    '.kpi-value{font-size:24px;font-weight:700;color:#FFFFFF;margin:2px 0;}'
    '.kpi-delta{font-size:12px;margin-bottom:6px;}'
    '.kpi-delta-pos{color:#2DC653;}'
    '.kpi-delta-neg{color:#FF4B4B;}'
    '.kpi-delta-zero{color:#AAAAAA;}'
    '.kpi-sub{font-size:11px;color:#888888;border-top:1px solid #333;padding-top:6px;margin-top:4px;}'
    '.kpi-sub-val{color:#CCCCCC;font-weight:600;}'
    '.kpi-prev{font-size:10px;color:#666666;margin-top:4px;line-height:1.5;}'
    '</style>'
    '<div class="kpi-row">'
    + "".join(_kpi_html_parts)
    + '</div>'
)
st.markdown(_kpi_row_html, unsafe_allow_html=True)

st.divider()

# --- Charts row (layout varies by category) ---
# Ammunition: Hourly | General Purpose | Caliber | Manufacturer | Projectile
# Guns: Hourly | Manufacturer | Caliber | Action | Capacity
# Magazines: Hourly | Manufacturer | Caliber | Capacity | Material
# Others: Hourly | General Purpose | Manufacturer | Fulfilled By
if category in ("Ammunition", "Guns", "Magazines", "Gun Parts", "Gear"):
    chart_cols = st.columns([30, 14, 14, 14, 14])
else:
    chart_cols = st.columns([40, 20, 20, 20])

# Helper: compute GP column and aggregate by metric


def _add_gp(df):
    df = df.copy()
    df["GP"] = df["NET_SALES"] - df["COST"]
    return df


def _agg_metric(df, group_col, metric):
    if df.empty:
        return pd.DataFrame()
    df = _add_gp(df)
    # Fill NaN so NULL dimension values appear in charts (matches PBI behavior)
    df[group_col] = df[group_col].fillna("(Blank)")
    if metric == "Orders":
        r = df.groupby(group_col)["ORDER_ID"].nunique().reset_index()
    elif metric == "Units":
        r = df.groupby(group_col)["UNITS"].sum().reset_index()
    else:
        col = "GP" if metric == "GP ($)" else "NET_SALES"
        r = df.groupby(group_col)[col].sum().reset_index()
    r.columns = [group_col, "VALUE"]
    return r.sort_values("VALUE", ascending=False)


def _render_hbar(df, group_col, metric, label, limit=15, df_compare=None,
                 filter_key=None, chart_key=None):
    """Render clickable Plotly horizontal bars. Click a bar to cross-filter."""
    st.subheader(f"{metric_label} / {label}")
    if df.empty:
        st.info("No data.")
        return
    agg = _agg_metric(df, group_col, metric).head(limit)
    if agg.empty:
        st.info("No data.")
        return

    labels = agg[group_col].tolist()
    values = [float(v) for v in agg["VALUE"].tolist()]
    total = sum(values)
    is_money = metric in ("$", "GP ($)", "GP ($) After VC")

    # Comparison map
    compare_map = {}
    if df_compare is not None and not df_compare.empty:
        agg_cmp = _agg_metric(df_compare, group_col, metric)
        if not agg_cmp.empty:
            compare_map = dict(zip(
                agg_cmp[group_col].tolist(),
                [float(v) for v in agg_cmp["VALUE"].tolist()],
            ))

    # Active filter highlighting
    active_val = (
        st.session_state.get(filter_key, "All") if filter_key else "All"
    )

    # Reverse for bottom-up (highest at top)
    labels_r = labels[::-1]
    values_r = values[::-1]

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
                st.session_state["_so_xf_pending"] = (filter_key, new_val)
                st.rerun()
        except (AttributeError, TypeError, IndexError):
            pass  # Older Streamlit — chart click not supported
    else:
        st.plotly_chart(fig, use_container_width=True)


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


# Analytical View chart (first column — Hourly / Bar Chart / Heat Map)
with chart_cols[0]:
    if analytical_view == "Hourly":
        if period == "TODAY":
            st.subheader(f"{metric_label} / Hourly")
            if not df_target.empty:
                hourly_target = _agg_time_metric(df_target, df_target["HOUR_BUCKET"].dt.hour, metric_toggle)
                fig = go.Figure()
                target_vals = hourly_target["VALUE"].tolist()
                target_text = [f"{int(round(v))}" for v in target_vals]
                fig.add_trace(go.Scatter(
                    x=[_hour_label(int(h)) for h in hourly_target["BUCKET"].tolist()],
                    y=target_vals,
                    name="TODAY", marker_color="#00d4aa",
                    mode="lines+markers+text", marker=dict(size=6),
                    text=target_text, textposition="top center",
                    textfont=dict(size=10, color="#00d4aa"),
                ))
                if not df_compare.empty:
                    hourly_compare = _agg_time_metric(
                        df_compare, df_compare["HOUR_BUCKET"].dt.hour, metric_toggle,
                    )
                    fig.add_trace(go.Scatter(
                        x=[_hour_label(int(h)) for h in hourly_compare["BUCKET"].tolist()],
                        y=hourly_compare["VALUE"].tolist(),
                        name="YESTERDAY", line=dict(color="gray", dash="dash"),
                    ))
                apply_theme(fig)
                fig.update_xaxes(
                    categoryorder="array",
                    categoryarray=[_hour_label(h) for h in range(24)],
                    title="Hour",
                )
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.info("No data for this period.")
        else:
            st.subheader(f"{metric_label} / Hourly")
            if not df_target.empty:
                # Average hourly across calendar days in the period (PBI excludes today)
                hourly_target = _agg_time_metric(df_target, df_target["HOUR_BUCKET"].dt.hour, metric_toggle)
                n_days_target = max((end_date - start_date).days, 1)
                if n_days_target > 1:
                    hourly_target["VALUE"] = hourly_target["VALUE"] / n_days_target
                fig = go.Figure()
                avg_vals = [round(float(v), 2) for v in hourly_target["VALUE"].tolist()]
                avg_text = [f"{int(round(v))}" for v in avg_vals]
                fig.add_trace(go.Scatter(
                    x=[_hour_label(int(h)) for h in hourly_target["BUCKET"].tolist()],
                    y=avg_vals,
                    name=f"AVG {period_label}", marker_color="#00d4aa",
                    mode="lines+markers+text", marker=dict(size=6),
                    text=avg_text, textposition="top center",
                    textfont=dict(size=10, color="#00d4aa"),
                ))
                if not df_compare.empty:
                    hourly_compare = _agg_time_metric(
                        df_compare, df_compare["HOUR_BUCKET"].dt.hour, metric_toggle,
                    )
                    # Use all calendar days in compare period
                    n_days_compare = max((compare_end - compare_start).days + 1, 1)
                    if n_days_compare > 1:
                        hourly_compare["VALUE"] = hourly_compare["VALUE"] / n_days_compare
                    fig.add_trace(go.Scatter(
                        x=[_hour_label(int(h)) for h in hourly_compare["BUCKET"].tolist()],
                        y=[round(float(v), 2) for v in hourly_compare["VALUE"].tolist()],
                        name=f"AVG {compare_label}", line=dict(color="gray", dash="dash"),
                    ))
                apply_theme(fig)
                fig.update_xaxes(
                    categoryorder="array",
                    categoryarray=[_hour_label(h) for h in range(24)],
                    title="",
                )
                fig.update_yaxes(title="")
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.info("No data for this period.")

    elif analytical_view == "Bar Chart":
        # Historical daily view — last 1 year, newest (left) → oldest (right)
        bar_end = today
        bar_start = today - timedelta(days=365)
        df_bar_raw = load_sales_data(bar_start, bar_end, statuses)
        # Apply same category filter
        if not df_bar_raw.empty:
            df_bar_raw = df_bar_raw[df_bar_raw["CATEGORY"] == category]
            if selected_storefronts:
                df_bar_raw = df_bar_raw[df_bar_raw["STOREFRONT"].isin(selected_storefronts)]
            if selected_store_ids:
                df_bar_raw = df_bar_raw[df_bar_raw["STORE_ID"].isin(selected_store_ids)]
            # Apply cross-filters to bar chart data
            _xf_bar = [
                ("MANUFACTURER", "so_xf_mfr"), ("VENDOR", "so_xf_vendor"),
                ("MANUFACTURER_SKU", "so_xf_sku"), ("CUSTOMER_EMAIL", "so_xf_cust"),
            ]
            for _col, _key in _xf_bar:
                _v = st.session_state.get(_key, "All")
                if _v != "All" and _col in df_bar_raw.columns:
                    df_bar_raw = df_bar_raw[df_bar_raw[_col] == _v]

        title_map = {"$": "Sales ($)", "GP ($)": "Gross Profit ($)", "Orders": "Orders", "Units": "Units Sold"}
        st.subheader(title_map.get(metric_toggle, metric_label))
        if not df_bar_raw.empty:
            df_bar = _add_gp(df_bar_raw)
            daily = df_bar.groupby(df_bar["CREATED_AT"].dt.date).agg(
                NET_SALES=("NET_SALES", "sum"),
                COST=("COST", "sum"),
                GP=("GP", "sum"),
                ORDERS=("ORDER_ID", pd.Series.nunique),
                UNITS=("UNITS", "sum"),
            ).reset_index()
            daily.columns = ["DAY", "NET_SALES", "COST", "GP", "ORDERS", "UNITS"]
            # Newest first (left → right = newest → oldest)
            daily = daily.sort_values("DAY", ascending=False).reset_index(drop=True)
            daily["MARGIN"] = (daily["GP"] / daily["NET_SALES"] * 100).fillna(0)
            val_col = {"$": "NET_SALES", "GP ($)": "GP", "Orders": "ORDERS", "Units": "UNITS"}[metric_toggle]
            # Format bar text labels
            bar_text = [f"{int(v):,}" for v in daily[val_col].tolist()]
            # X-axis: numeric positions with day/month labels
            x_pos = list(range(len(daily)))
            tick_labels = []
            prev_month = None
            for d in daily["DAY"]:
                mon = d.strftime("%b")
                if mon != prev_month:
                    tick_labels.append(f"{d.strftime('%-d')}<br>{mon}")
                    prev_month = mon
                else:
                    tick_labels.append(d.strftime("%-d"))
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=x_pos, y=daily[val_col].tolist(),
                name=metric_label, marker_color="#00d4aa",
                text=bar_text, textposition="outside", textfont=dict(size=10),
            ))
            fig.add_trace(go.Scatter(
                x=x_pos, y=daily["MARGIN"].tolist(), name="Margin %", yaxis="y2",
                mode="lines+markers+text",
                text=[f"{m:.0f}%" for m in daily["MARGIN"].tolist()],
                textposition="top center", line=dict(color="white", width=2),
                marker=dict(color="white", size=6),
                textfont=dict(size=10, color="white"),
            ))
            # Initial view: last 14 days (positions 0–13), scroll right for history
            visible_end = min(13, len(x_pos) - 1)
            # Compute y-axis ranges from visible window only
            vis_vals = daily[val_col].iloc[:visible_end + 1]
            vis_margin = daily["MARGIN"].iloc[:visible_end + 1]
            max_val = vis_vals.max() if not vis_vals.empty else 1
            y1_max = max_val * 1.35
            margin_max = vis_margin.max() if not vis_margin.empty else 100
            y2_range_max = margin_max * 1.6 if margin_max > 0 else 100
            apply_theme(fig, height=400, margin=dict(l=0, r=40, t=30, b=0))
            fig.update_layout(
                yaxis=dict(title="", range=[0, y1_max]),
                yaxis2=dict(
                    title="", overlaying="y", side="right",
                    range=[0, y2_range_max], ticksuffix="%", showgrid=False,
                    **secondary_axis_style(),
                ),
                xaxis=dict(
                    title="", tickmode="array", tickvals=x_pos, ticktext=tick_labels,
                    range=[-0.5, visible_end + 0.5],
                    rangeslider=dict(visible=True, thickness=0.08),
                ),
                bargap=0.3,
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data.")

    else:  # Heat Map
        st.subheader(f"{metric_label} / Heat Map")
        if not df_target.empty:
            df_heat = _add_gp(df_target)
            df_heat["HOUR"] = df_heat["HOUR_BUCKET"].dt.hour
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

# Category-specific charts (columns 1+ vary by category)
# Manufacturer and Vendor charts are clickable → set cross-filters
_MFR = dict(filter_key="so_xf_mfr", chart_key="so_mfr_chart")
_VND = dict(filter_key="so_xf_vendor", chart_key="so_vendor_chart")

if category == "Ammunition":
    # Ammunition: General Purpose | Caliber | Manufacturer | Projectile
    with chart_cols[1]:
        _render_hbar(df_target, "GENERAL_PURPOSE_AMMO", metric_toggle, "General Purpose", df_compare=df_compare)
    with chart_cols[2]:
        _render_hbar(df_target, "CALIBER", metric_toggle, "Caliber", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[4]:
        _render_hbar(df_target, "PROJECTILE", metric_toggle, "Projectile", df_compare=df_compare)
elif category == "Guns":
    # Guns: Manufacturer | Caliber | Action | Capacity
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "CALIBER", metric_toggle, "Caliber", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "GUN_ACTION", metric_toggle, "Action", df_compare=df_compare)
    with chart_cols[4]:
        _render_hbar(df_target, "CAPACITY", metric_toggle, "Capacity", df_compare=df_compare)
elif category == "Magazines":
    # Magazines: Manufacturer | Caliber | Capacity | Material
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "CALIBER", metric_toggle, "Caliber", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "CAPACITY", metric_toggle, "Capacity", df_compare=df_compare)
    with chart_cols[4]:
        _render_hbar(df_target, "MATERIAL", metric_toggle, "Material", df_compare=df_compare)
elif category == "Gear":
    # Gear: Manufacturer | Color | Material | Fulfilled By
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "COLOR", metric_toggle, "Color", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "MATERIAL", metric_toggle, "Material", df_compare=df_compare)
    with chart_cols[4]:
        _render_hbar(df_target, "VENDOR", metric_toggle, "Fulfilled By", limit=6, df_compare=df_compare, **_VND)
elif category == "Gun Parts":
    # Gun Parts: Manufacturer | Part | Material | Fulfilled By
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "GUN_PART", metric_toggle, "Part", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "MATERIAL", metric_toggle, "Material", df_compare=df_compare)
    with chart_cols[4]:
        _render_hbar(df_target, "VENDOR", metric_toggle, "Fulfilled By", limit=6, df_compare=df_compare, **_VND)
elif category == "Loading Components":
    # Load Comp: Manufacturer | Categories | Material
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "CATEGORIES", metric_toggle, "Categories", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "MATERIAL", metric_toggle, "Material", df_compare=df_compare)
elif category == "Optics":
    # Optics: Manufacturer | Category | Fulfilled By
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "PRIMARY_CATEGORY", metric_toggle, "Category", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "VENDOR", metric_toggle, "Fulfilled By", limit=6, df_compare=df_compare, **_VND)
elif category == "Survival":
    # Survival: Manufacturer | Model | Material
    with chart_cols[1]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[2]:
        _render_hbar(df_target, "MODEL", metric_toggle, "Model", df_compare=df_compare)
    with chart_cols[3]:
        _render_hbar(df_target, "MATERIAL", metric_toggle, "Material", df_compare=df_compare)
else:
    # Other categories: General Purpose | Manufacturer | Fulfilled By
    with chart_cols[1]:
        _render_hbar(df_target, "GENERAL_PURPOSE", metric_toggle, "General Purpose", df_compare=df_compare)
    with chart_cols[2]:
        _render_hbar(df_target, "MANUFACTURER", metric_toggle, "Manufacturer", df_compare=df_compare, **_MFR)
    with chart_cols[3]:
        _render_hbar(df_target, "VENDOR", metric_toggle, "Fulfilled By", limit=6, df_compare=df_compare, **_VND)

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

    sku = df.groupby("MANUFACTURER_SKU").agg(
        NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
        ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"),
    ).reset_index()
    sku["GP"] = sku["NET_SALES"] - sku["COST"]
    sku["MARGIN"] = (sku["GP"] / sku["NET_SALES"] * 100).fillna(0)
    sku["PU"] = (sku["NET_SALES"] / sku["UNITS"]).fillna(0)
    sku = sku.sort_values("NET_SALES", ascending=False).head(25)
    top = set(sku["MANUFACTURER_SKU"])

    det = df[df["MANUFACTURER_SKU"].isin(top)].groupby(
        ["MANUFACTURER_SKU", "PRODUCT_NAME"]
    ).agg(
        NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
        ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"),
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
        cs = dc.groupby("MANUFACTURER_SKU").agg(
            NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
            ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"),
        ).reset_index()
        cs["GP"] = cs["NET_SALES"] - cs["COST"]
        cmp_s = {r["MANUFACTURER_SKU"]: r for _, r in cs.iterrows()}
        cd = dc.groupby(["MANUFACTURER_SKU", "PRODUCT_NAME"]).agg(
            NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
            ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"),
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

    st.markdown(
        '<style>'
        '.pp-tbl{font-size:13px;width:100%;}'
        '.pp-row{display:grid;'
        'grid-template-columns:1fr 110px 90px 70px 70px 75px 85px;'
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
        '</div>'
        + "".join(rows)
        + f'<div class="pp-row pp-tot"><div>Total</div>'
        f'<div class="pp-c">${t_ns:,.0f}</div>'
        f'<div class="pp-c">${t_gp:,.0f}</div>'
        f'<div class="pp-c">{t_or:,}</div>'
        f'<div class="pp-c">{t_un:,}</div>'
        f'<div class="pp-c">{t_mg:.2f}%</div>'
        f'<div class="pp-c">${t_pu:,.0f}</div>'
        '</div></div>',
        unsafe_allow_html=True,
    )


_render_product_perf(
    df_target, df_compare, f"Product Performance / {period_label}",
)

# --- Geographic / Customer Overview ---
st.divider()
geo_left, geo_right = st.columns([3, 4])

with geo_left:
    geo_view = st.radio("", ["Geographic", "Customer"], horizontal=True, key="so_geo_view")

    if not df_target.empty:
        # State / City / Zip filters
        filter_geo = st.columns(3)
        states = sorted(df_target["REGION"].dropna().unique().tolist())
        with filter_geo[0]:
            sel_state = st.selectbox("STATE", ["All"] + states, key="so_geo_state")
        geo_df = df_target if sel_state == "All" else df_target[df_target["REGION"] == sel_state]

        cities = sorted(geo_df["CITY"].dropna().unique().tolist())
        with filter_geo[1]:
            sel_city = st.selectbox("CITY", ["All"] + cities, key="so_geo_city")
        if sel_city != "All":
            geo_df = geo_df[geo_df["CITY"] == sel_city]

        zips = sorted(geo_df["POSTCODE"].dropna().unique().tolist())
        with filter_geo[2]:
            sel_zip = st.selectbox("ZIP CODE", ["All"] + zips, key="so_geo_zip")
        if sel_zip != "All":
            geo_df = geo_df[geo_df["POSTCODE"] == sel_zip]

        if geo_view == "Geographic":
            st.caption(f"Geographic Overview / {period_label}")
            geo_agg = (
                geo_df.groupby("REGION")
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     ORDERS=("ORDER_ID", "nunique"), UNITS=("UNITS", "sum"))
                .reset_index()
            )
            geo_agg.rename(columns={"REGION": "STATE"}, inplace=True)
            geo_agg["GP"] = geo_agg["NET_SALES"] - geo_agg["COST"]
            geo_agg["MARGIN"] = (geo_agg["GP"] / geo_agg["NET_SALES"] * 100).fillna(0).round(2)
            geo_agg = geo_agg.sort_values("NET_SALES", ascending=False)

            totals = pd.DataFrame([{
                "STATE": "Total",
                "NET_SALES": geo_agg["NET_SALES"].sum(),
                "GP": geo_agg["GP"].sum(),
                "ORDERS": geo_agg["ORDERS"].sum(),
                "UNITS": geo_agg["UNITS"].sum(),
                "MARGIN": (geo_agg["GP"].sum() / geo_agg["NET_SALES"].sum() * 100) if geo_agg["NET_SALES"].sum() else 0,
            }])
            geo_display = pd.concat([geo_agg, totals], ignore_index=True)
            cols = ["STATE", "NET_SALES", "GP", "ORDERS", "UNITS", "MARGIN"]
            dark_dataframe(
                geo_display[cols],
                fmt={"NET_SALES": "${:,.0f}", "GP": "${:,.0f}", "MARGIN": "{:.2f}%"},
                height=250,
            )
        else:  # Customer
            st.caption(f"Customer Overview / {period_label}")
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
            top_emails = set(cust_agg["CUSTOMER_EMAIL"])
            cust_det = (
                geo_df[geo_df["CUSTOMER_EMAIL"].isin(top_emails)]
                .groupby(["CUSTOMER_EMAIL", "ORDER_ID"])
                .agg(NET_SALES=("NET_SALES", "sum"), COST=("COST", "sum"),
                     UNITS=("UNITS", "sum"))
                .reset_index()
            )
            cust_det["GP"] = cust_det["NET_SALES"] - cust_det["COST"]
            t_ns = cust_agg["NET_SALES"].sum()
            t_gp = cust_agg["GP"].sum()
            t_or = int(cust_agg["ORDERS"].sum())
            t_un = int(cust_agg["UNITS"].sum())
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
        import random
        random.seed(42)
        map_df = map_df.copy()
        map_df["LAT"] = [
            float(lat) + random.uniform(-0.3, 0.3)
            for lat in map_df["LAT"]
        ]
        map_df["LON"] = [
            float(lon) + random.uniform(-0.3, 0.3)
            for lon in map_df["LON"]
        ]
        if not map_df.empty:
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
                sis_map = pd.DataFrame({
                    "latitude": lat_list,
                    "longitude": lon_list,
                    "size": size_list,
                })
                try:
                    st.map(sis_map, size="size")
                except TypeError:
                    st.map(sis_map[["latitude", "longitude"]])
            else:
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
        st.checkbox(sf, key=f"so_sf_{sf}")

if store_names:
    st.markdown("**STORE**")
    store_ui_cols = st.columns(len(store_names))
    for i, name in enumerate(store_names):
        with store_ui_cols[i]:
            st.checkbox(name, key=f"so_store_{name}")

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
        f" | {period_label} vs {compare_label} | Data cached 5 min"
    )
else:
    st.caption(f"Last Update: {now:%m/%d/%y %H:%M:%S} | No data for selected filters")
