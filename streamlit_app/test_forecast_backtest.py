"""Backtest validation for SNOWFLAKE.ML.FORECAST demand model.

Trains on data through a cutoff date, predicts the next N days,
compares to actuals, and reports MAPE per caliber.

Run from ammodepot/:
  set -a && source .env && set +a && uv run python ../streamlit_app/test_forecast_backtest.py
"""

import os
from pathlib import Path
from datetime import date

from cryptography.hazmat.primitives import serialization
from snowflake.connector import connect

# ── Config ───────────────────────────────────────────────────────────────────
CUTOFF_DATE = "2026-03-15"       # Train on data up to this date
FORECAST_DAYS = 30               # Predict this many days forward
MIN_MAPE_THRESHOLD = 20.0        # Target: MAPE < 20%

# ── Connect ──────────────────────────────────────────────────────────────────
key_path = Path(os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"])
passphrase = os.environ.get("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE", "").encode()
with open(key_path, "rb") as f:
    pk = serialization.load_pem_private_key(f.read(), password=passphrase or None)
pk_bytes = pk.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
)

conn = connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    private_key=pk_bytes,
    warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    database="AD_ANALYTICS",
    schema="GOLD",
    role=os.environ["SNOWFLAKE_ROLE"],
)
cur = conn.cursor()

print("=" * 80)
print(f"FORECAST BACKTEST — Cutoff: {CUTOFF_DATE}, Horizon: {FORECAST_DAYS} days")
print("=" * 80)
print()

# ── Step 1: Create backtest training view (data up to cutoff) ────────────────
print("Step 1: Creating backtest training view...")
cur.execute(f"""
    CREATE OR REPLACE TEMPORARY VIEW V_BACKTEST_TRAINING AS
    SELECT SALE_DATE, CALIBER, UNITS_SOLD
    FROM V_DAILY_SALES_BY_CALIBER
    WHERE SALE_DATE <= '{CUTOFF_DATE}'
""")

# Count calibers with enough data
cur.execute(f"""
    SELECT CALIBER, COUNT(DISTINCT SALE_DATE) AS DAYS
    FROM V_BACKTEST_TRAINING
    GROUP BY CALIBER
    HAVING DAYS >= 730
    ORDER BY DAYS DESC
""")
eligible = cur.fetchall()
print(f"  Calibers with 730+ days: {len(eligible)}")

cur.execute(f"""
    SELECT COUNT(DISTINCT CALIBER), SUM(UNITS_SOLD)
    FROM V_BACKTEST_TRAINING
    WHERE CALIBER IN (SELECT CALIBER FROM V_BACKTEST_TRAINING GROUP BY CALIBER HAVING COUNT(DISTINCT SALE_DATE) >= 730)
""")
cov = cur.fetchone()
print(f"  Coverage: {cov[0]} calibers, {cov[1]:,.0f} total units in training data")
print()

# ── Step 2: Train backtest model ─────────────────────────────────────────────
print("Step 2: Training backtest FORECAST model (this may take 30-60s)...")
try:
    cur.execute("""
        CREATE OR REPLACE SNOWFLAKE.ML.FORECAST BACKTEST_FORECAST(
            INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'AD_ANALYTICS.GOLD.V_BACKTEST_TRAINING'),
            SERIES_COLNAME => 'CALIBER',
            TIMESTAMP_COLNAME => 'SALE_DATE',
            TARGET_COLNAME => 'UNITS_SOLD'
        )
    """)
    print("  Model trained successfully.")
except Exception as e:
    print(f"  ERROR: {e}")
    conn.close()
    exit(1)
print()

# ── Step 3: Generate predictions ─────────────────────────────────────────────
print(f"Step 3: Generating {FORECAST_DAYS}-day predictions...")
cur.execute(f"""
    SELECT SERIES AS CALIBER, TS AS FORECAST_DATE, FORECAST AS PREDICTED_UNITS
    FROM TABLE(BACKTEST_FORECAST!FORECAST(FORECASTING_PERIODS => {FORECAST_DAYS}))
""")
predictions = cur.fetchall()
pred_cols = [d[0] for d in cur.description]
print(f"  Generated {len(predictions)} prediction rows")
print()

# ── Step 4: Get actuals for the forecast period ──────────────────────────────
print("Step 4: Fetching actuals for comparison...")
cur.execute(f"""
    SELECT CALIBER, SALE_DATE, UNITS_SOLD
    FROM V_DAILY_SALES_BY_CALIBER
    WHERE SALE_DATE > '{CUTOFF_DATE}'
      AND SALE_DATE <= DATEADD('DAY', {FORECAST_DAYS}, '{CUTOFF_DATE}')
""")
actuals = cur.fetchall()
print(f"  Fetched {len(actuals)} actual rows")
print()

# ── Step 5: Calculate MAPE per caliber ───────────────────────────────────────
print("Step 5: Calculating MAPE per caliber...")
print()

# Build lookup: (caliber, date) → actual
actual_map = {}
for cal, dt, units in actuals:
    key = (cal, str(dt))
    actual_map[key] = float(units)

# Build lookup: (caliber, date) → predicted
pred_map = {}
for row in predictions:
    cal, dt, pred = row[0], str(row[1])[:10], float(row[2])
    pred_map[(cal, dt)] = pred

# Calculate MAPE per caliber
from collections import defaultdict
errors = defaultdict(list)
for (cal, dt), actual in actual_map.items():
    pred = pred_map.get((cal, dt))
    if pred is not None and actual > 0:
        ape = abs(actual - pred) / actual * 100
        errors[cal].append(ape)

# Sort by MAPE
mape_results = []
for cal, apes in errors.items():
    mape = sum(apes) / len(apes)
    mape_results.append((cal, mape, len(apes)))

mape_results.sort(key=lambda x: x[1])

# Report
pass_count = sum(1 for _, m, _ in mape_results if m < MIN_MAPE_THRESHOLD)
fail_count = len(mape_results) - pass_count

print(f"{'CALIBER':<40s} {'MAPE':>8s} {'DAYS':>6s} {'STATUS':>8s}")
print("-" * 65)
for cal, mape, days in mape_results[:30]:
    status = "PASS" if mape < MIN_MAPE_THRESHOLD else "FAIL"
    print(f"{cal:<40s} {mape:>7.1f}% {days:>5d}  {status:>7s}")

if len(mape_results) > 30:
    print(f"  ... and {len(mape_results) - 30} more calibers")

print()
print("=" * 80)
overall_mape = sum(m for _, m, _ in mape_results) / len(mape_results) if mape_results else 0
print(f"Overall MAPE: {overall_mape:.1f}%")
print(f"Calibers tested: {len(mape_results)}")
print(f"Pass (<{MIN_MAPE_THRESHOLD}%): {pass_count} | Fail: {fail_count}")
print(f"Pass rate: {pass_count / len(mape_results) * 100:.0f}%" if mape_results else "No data")
print("=" * 80)

# Cleanup
cur.execute("DROP SNOWFLAKE.ML.FORECAST IF EXISTS BACKTEST_FORECAST")
conn.close()
