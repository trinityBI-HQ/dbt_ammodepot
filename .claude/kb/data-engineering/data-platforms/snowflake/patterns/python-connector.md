# Python Connector

> **Purpose**: Native Python SDK for Snowflake database operations
> **MCP Validated**: 2026-02-19

## When to Use

- Python applications needing direct Snowflake access
- Data pipelines with pandas DataFrames
- Automation scripts for ETL and administration
- Web applications with Snowflake backend

## Implementation

```python
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas, pd_writer
import pandas as pd

# Basic connection
conn = snowflake.connector.connect(
    account='account_locator',  # e.g., 'xy12345.us-east-1'
    user='username',
    password='password',  # Or use authenticator for SSO
    warehouse='compute_wh',
    database='analytics_db',
    schema='public',
    role='data_engineer'
)

# Connection with key-pair authentication (recommended)
conn = snowflake.connector.connect(
    account='account_locator',
    user='username',
    private_key_file='/path/to/rsa_key.p8',
    private_key_file_pwd='key_password',
    warehouse='compute_wh',
    database='analytics_db'
)

# Execute queries
cursor = conn.cursor()
try:
    cursor.execute("SELECT * FROM orders WHERE order_date = %s", ('2024-01-15',))
    results = cursor.fetchall()
    for row in results:
        print(row)
finally:
    cursor.close()

# Fetch as pandas DataFrame
cursor = conn.cursor()
cursor.execute("SELECT * FROM orders LIMIT 1000")
df = cursor.fetch_pandas_all()
cursor.close()

# Write pandas DataFrame to Snowflake
df = pd.DataFrame({
    'order_id': [1, 2, 3],
    'amount': [100.0, 200.0, 150.0],
    'order_date': pd.to_datetime(['2024-01-15', '2024-01-16', '2024-01-17'])
})

success, num_chunks, num_rows, output = write_pandas(
    conn=conn,
    df=df,
    table_name='ORDERS',
    database='ANALYTICS_DB',
    schema='STAGING',
    auto_create_table=True,
    overwrite=False  # Append mode
)
```

## Configuration

| Parameter | Description |
|-----------|-------------|
| `account` | Account locator (e.g., `xy12345.us-east-1`) |
| `authenticator` | `snowflake` (default), `externalbrowser`, `oauth` |
| `warehouse` | Default warehouse for queries |
| `role` | Default role for session |
| `autocommit` | Auto-commit transactions (default: True) |
| `client_session_keep_alive` | Keep connection alive (default: False) |

## Example Usage

```python
import snowflake.connector
from contextlib import contextmanager
import os

@contextmanager
def snowflake_connection():
    """Context manager for Snowflake connections."""
    conn = snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        user=os.environ['SNOWFLAKE_USER'],
        password=os.environ['SNOWFLAKE_PASSWORD'],
        warehouse=os.environ.get('SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH'),
        database=os.environ.get('SNOWFLAKE_DATABASE', 'ANALYTICS'),
        schema=os.environ.get('SNOWFLAKE_SCHEMA', 'PUBLIC')
    )
    try:
        yield conn
    finally:
        conn.close()

def load_data_to_snowflake(df: pd.DataFrame, table: str):
    """Load DataFrame to Snowflake with upsert logic."""
    with snowflake_connection() as conn:
        # Create temp table and merge
        temp_table = f"{table}_TEMP"
        write_pandas(conn, df, temp_table, auto_create_table=True, overwrite=True)

        conn.cursor().execute(f"""
            MERGE INTO {table} t
            USING {temp_table} s ON t.id = s.id
            WHEN MATCHED THEN UPDATE SET t.value = s.value
            WHEN NOT MATCHED THEN INSERT (id, value) VALUES (s.id, s.value)
        """)

        conn.cursor().execute(f"DROP TABLE IF EXISTS {temp_table}")

# Batch execution with executemany
with snowflake_connection() as conn:
    cursor = conn.cursor()
    data = [(1, 'A'), (2, 'B'), (3, 'C')]
    cursor.executemany(
        "INSERT INTO lookup (id, code) VALUES (%s, %s)",
        data
    )
```

## See Also

- [spark-connector](../patterns/spark-connector.md)
- [stages](../concepts/stages.md)
