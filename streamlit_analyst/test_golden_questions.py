"""Automated golden question test for Cortex Analyst.

Connects to Snowflake using ammodepot/.env credentials, calls the Cortex
Analyst API for each question, executes the returned SQL, and reports results.

Run: cd ammodepot && set -a && source .env && set +a && uv run python ../streamlit_analyst/test_golden_questions.py
"""

import os
import time
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from snowflake.connector import connect
import requests

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

token = conn.rest.token
account = os.environ["SNOWFLAKE_ACCOUNT"]
api_url = f"https://{account}.snowflakecomputing.com/api/v2/cortex/analyst/message"
semantic_view = "AD_ANALYTICS.GOLD.AMMODEPOT_ANALYST"

# ── Golden Questions ─────────────────────────────────────────────────────────
questions = [
    # Original 15
    "What is total revenue today?",
    "What is our gross margin this month?",
    "Top 10 products by revenue this week",
    "How many units of 9mm are in stock?",
    "Which vendors have the longest lead times?",
    "Total orders yesterday vs day before",
    "Revenue by category this month",
    "How many customers are At-Risk Regular?",
    "Show me open POs not yet received",
    "Top 5 manufacturers by units sold MTD",
    "What is average order value today?",
    "Sales by hour today",
    "Top categories by revenue today",
    "Shipping revenue as % of net sales today",
    "GP after variable cost today",
    # PBI Top 20 additions
    "Revenue MTD vs prior month",
    "Revenue YTD vs prior year",
    "Daily revenue trend last 30 days",
    "Revenue by caliber this month",
    "Product margin by manufacturer",
    "Revenue by storefront this month",
    "Top states by revenue this month",
    "Average order value by store",
    "Total inventory value on hand",
    "Customer count by segment",
]

headers = {
    "Authorization": f'Snowflake Token="{token}"',
    "Content-Type": "application/json",
}

results = []
for i, q in enumerate(questions, 1):
    start = time.time()
    try:
        resp = requests.post(
            api_url,
            headers=headers,
            json={
                "messages": [
                    {"role": "user", "content": [{"type": "text", "text": q}]}
                ],
                "semantic_view": semantic_view,
            },
            timeout=90,
        )
        api_ms = int((time.time() - start) * 1000)

        if not resp.ok:
            results.append({
                "q": i, "question": q, "status": "API_ERROR",
                "detail": resp.text[:300], "api_ms": api_ms, "sql_ms": 0,
            })
            continue

        data = resp.json()
        text, sql = None, None
        for block in data.get("message", {}).get("content", []):
            if block["type"] == "text":
                text = block["text"]
            elif block["type"] == "sql":
                sql = block["statement"]

        if not sql:
            results.append({
                "q": i, "question": q, "status": "NO_SQL",
                "detail": (text or "")[:300], "api_ms": api_ms, "sql_ms": 0,
            })
            continue

        # Execute the SQL
        sql_start = time.time()
        try:
            cur = conn.cursor()
            cur.execute(sql)
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]
            sql_ms = int((time.time() - sql_start) * 1000)
            cur.close()

            row_count = len(rows)
            sample = dict(zip(cols, rows[0])) if rows else {}
            sample_str = {k: str(v)[:60] for k, v in sample.items()}

            results.append({
                "q": i, "question": q, "status": "PASS",
                "rows": row_count, "columns": cols,
                "sample": sample_str,
                "api_ms": api_ms, "sql_ms": sql_ms,
            })
        except Exception as e:
            sql_ms = int((time.time() - sql_start) * 1000)
            results.append({
                "q": i, "question": q, "status": "SQL_ERROR",
                "detail": str(e)[:300], "api_ms": api_ms, "sql_ms": sql_ms,
            })

    except Exception as e:
        results.append({
            "q": i, "question": q, "status": "EXCEPTION",
            "detail": str(e)[:300], "api_ms": 0, "sql_ms": 0,
        })

# ── Report ───────────────────────────────────────────────────────────────────
print("=" * 80)
print("CORTEX ANALYST GOLDEN QUESTION TEST RESULTS")
print("=" * 80)

pass_count = sum(1 for r in results if r["status"] == "PASS")
fail_count = len(results) - pass_count
total_api = sum(r.get("api_ms", 0) for r in results)
total_sql = sum(r.get("sql_ms", 0) for r in results)

print(f"\nSummary: {pass_count} PASS / {fail_count} FAIL out of {len(results)} questions")
print(f"Total time: API={total_api}ms, SQL={total_sql}ms, Combined={total_api + total_sql}ms")
print(f"Avg per question: {(total_api + total_sql) // len(results)}ms\n")

for r in results:
    icon = "PASS" if r["status"] == "PASS" else "FAIL"
    print(f"  [{icon}] Q{r['q']:2d}: {r['question']}")
    if r["status"] == "PASS":
        print(f"         {r['rows']} rows | API={r['api_ms']}ms SQL={r['sql_ms']}ms")
        print(f"         {r['sample']}")
    else:
        print(f"         {r['status']}: {r.get('detail', 'N/A')[:200]}")
    print()

conn.close()
