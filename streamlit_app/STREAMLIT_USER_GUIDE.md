# Ammunition Depot Analytics Dashboard — User Guide
[Docs](https://docs.google.com/document/d/11j8DM8Ue1IfEF9EtBcH3kp39EdLX9Dib7acBFijib1Q/edit?usp=sharing)

## How It Works

The dashboard **connects directly to Snowflake** — there are no manual exports, no scheduled refreshes to wait for, and no intermediate files. When data arrives in Snowflake (every ~5 minutes via Airbyte), the dashboard reflects it automatically. Just open the page and you're looking at the latest data.

---

## Getting Started

The dashboard has **3 pages**, accessible from the sidebar on the left:

1. **Today / Yesterday** — Real-time daily sales
2. **Sales Overview** — Historical sales by category
3. **Inventory** — Stock levels, vendor analysis, and open purchase orders

---

## Page 1: Today / Yesterday

Real-time view of today's (or yesterday's) sales performance.

### Filters (top of page)

| Filter | Options | Default |
|---|---|---|
| **Period** | Today, Yesterday | Today |
| **Order Status** | All statuses | COMPLETE, PROCESSING, UNVERIFIED |
| **Store** | All stores | All |
| **Category** | All product categories | All |
| **State** | US states | All |

### What you'll see

- **KPI cards** — Total Revenue, Orders, Items, AOV (Average Order Value), and comparison vs. the other day (Today vs. Yesterday or vice versa)
- **Hourly Sales chart** — Revenue broken down by hour, with an average line
- **Customer Map** — Geographic distribution of orders by ZIP code
- **Product Performance table** — Top-selling products with revenue, quantity, and order count

### Footer

Shows **Last Update** (when the dashboard data was refreshed) and **Last Order** (timestamp of the most recent order in the database), both in Eastern Time.

---

## Page 2: Sales Overview

Historical sales analysis with category-specific views — mirrors the Power BI "Sales Overview" report.

### Filters (top of page)

| Filter | Options | Default |
|---|---|---|
| **Category** | Ammunition, Guns, Magazines, Gun Parts, Gear, Optics, Load Comp, Survival | Ammunition |
| **Period** | TODAY, MTD, YTD | MTD |
| **Order Status** | All statuses | COMPLETE, PROCESSING, UNVERIFIED |
| **Store** | All stores | All |
| **State** | US states | All |

### What you'll see

- **KPI cards** — Revenue, Orders, AOV, Items, and comparison with the previous period (e.g., this MTD vs. last month's MTD)
- **Revenue by Day chart** — Daily revenue trend for the selected period
- **Category-specific charts** — Each category has its own chart layout:
  - **Ammunition**: Revenue by Caliber + by Manufacturer
  - **Guns**: Revenue by Type + by Manufacturer
  - **Magazines**: Revenue by Caliber + by Brand
  - *(similar breakdowns for all 8 categories)*
- **Top Products table** — Best sellers within the selected category

---

## Page 3: Inventory

Three tabs covering stock management, vendor purchasing, and open orders.

### Tab 1: Inventory

**Overview of current stock levels.**

- **KPI cards** — Total SKUs, Available Qty, Inventory Cost
- **Charts** — Inventory breakdown by Category, Caliber, and Projectile type
- **Tables** — Full inventory overview, Low Stock alerts, and Overstock alerts

### Tab 2: Vendor Analysis

**Purchasing history by vendor, for the Ammunition category.**

| Filter | Options | Default |
|---|---|---|
| **Receipt Period** | Last 30 / 90 / 180 / 365 days, Custom | Last 90 days |
| **Vendor** | All ammunition vendors | All |

- **QTY and Cost Per Receipts** — Dual-axis chart showing quantity received and cost over time
- **Individual POs** — Detailed view of each purchase order
- **Breakdown tables** — By Vendor, by Caliber, and by Part SKU

### Tab 3: Open POs

**Outstanding purchase orders and inventory projections, for the Ammunition category.**

| Filter | Options | Default |
|---|---|---|
| **Sales Period** | Yesterday, 7 Days, MTD, YTD, Custom | YTD |
| **PO Status** | Select All, OVERDUE, REGULAR | Select All |
| **Vendor** | All vendors | All |

- **Inventory Projections chart** — Projected stock levels based on current sales velocity and incoming POs
- **Date Projection** — Estimated days of stock remaining
- **Total POs** — Summary of open purchase orders
- **Breakdown tables** — By Vendor, by Caliber, and by Part SKU

---

## Tips

- **Data refreshes every ~5 minutes** — you're always looking at near real-time data
- **Filters apply instantly** — no need to click a "Refresh" button
- **Full-width layout** — charts and tables use the full screen width
- **Default filters match Power BI** — Order Status defaults to COMPLETE, PROCESSING, UNVERIFIED, same as the previous reports
- **Category icons** — Each category shows an emoji icon in the dropdown for quick identification

---

## Support

For questions or issues with the dashboard, contact your TrinityBI team.
