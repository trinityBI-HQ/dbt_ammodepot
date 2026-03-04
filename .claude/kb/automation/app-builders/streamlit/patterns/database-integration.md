# Database Integration Pattern

> **Purpose**: Connect to databases using st.connection, secrets.toml, and caching strategies
> **MCP Validated**: 2026-03-03

## When to Use

- Querying SQL databases (PostgreSQL, MySQL, SQLite, Snowflake)
- Building data apps backed by a warehouse or transactional database
- Managing credentials securely with secrets.toml
- Combining cached queries with interactive filters

## Implementation

```python
import streamlit as st

# --- SQL Database (PostgreSQL, MySQL, SQLite) ---
# Requires: pip install streamlit[sql] (includes SQLAlchemy)
conn = st.connection("my_db", type="sql")

# Query with automatic caching (TTL in seconds)
df = conn.query("SELECT * FROM users WHERE active = true", ttl=600)
st.dataframe(df)

# Parameterized queries
user_df = conn.query(
    "SELECT * FROM users WHERE department = :dept",
    params={"dept": selected_dept},
    ttl=300,
)
```

## Secrets Configuration

```toml
# .streamlit/secrets.toml (never commit this file)

# SQL Connection
[connections.my_db]
type = "sql"
dialect = "postgresql"
host = "localhost"
port = 5432
database = "analytics"
username = "app_user"
password = "secret123"

# Snowflake Connection
[connections.snowflake]
type = "snowflake"
account = "iwb48385.us-east-1"
user = "SVC_APP"
password = "secret"
warehouse = "ETL_WH"
database = "AD_ANALYTICS"
schema = "GOLD"
role = "POWERBI_ROLE"

# API Keys
[api]
openai_key = "sk-..."
```

## Snowflake Connection

```python
import streamlit as st

# Built-in SnowflakeConnection (no extra install for Streamlit in Snowflake)
conn = st.connection("snowflake", type="snowflake")

# Query returns a pandas DataFrame
df = conn.query(
    "SELECT * FROM AD_ANALYTICS.GOLD.F_SALES WHERE ORDER_DATE >= :start_date",
    params={"start_date": "2025-01-01"},
    ttl=600,
)

st.dataframe(df)

# Access the underlying Snowpark session for advanced operations
session = conn.session()
snow_df = session.table("AD_ANALYTICS.GOLD.D_PRODUCT")
```

## Custom Connection Class

```python
import streamlit as st
from streamlit.connections import BaseConnection
import requests

class APIConnection(BaseConnection[requests.Session]):
    """Custom connection for a REST API."""

    def _connect(self, **kwargs) -> requests.Session:
        session = requests.Session()
        session.headers.update({
            "Authorization": f"Bearer {self._secrets['api_key']}",
            "Content-Type": "application/json",
        })
        return session

    def query(self, endpoint: str, ttl: int = 300) -> dict:
        @st.cache_data(ttl=ttl)
        def _query(endpoint: str) -> dict:
            response = self._instance.get(
                f"{self._secrets['base_url']}/{endpoint}"
            )
            response.raise_for_status()
            return response.json()
        return _query(endpoint)

# Usage
conn = st.connection("my_api", type=APIConnection)
data = conn.query("users", ttl=60)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `ttl` | `None` | Cache duration in seconds |
| `type` | Required | `"sql"`, `"snowflake"`, or custom class |
| `autocommit` | `True` | Auto-commit SQL operations |

## Caching Strategy with Database

```python
@st.cache_data(ttl=600)
def get_summary(start_date, end_date, category):
    """Cache query results keyed by filter parameters."""
    conn = st.connection("my_db", type="sql")
    return conn.query(
        """
        SELECT category, SUM(revenue) as total_revenue, COUNT(*) as order_count
        FROM sales
        WHERE order_date BETWEEN :start AND :end
          AND category = :cat
        GROUP BY category
        """,
        params={"start": start_date, "end": end_date, "cat": category},
        ttl=0,  # let outer decorator handle caching
    )

# Filters change the cache key -- new combo = new query
summary = get_summary(start_date, end_date, selected_category)
```

## Write Operations

```python
conn = st.connection("my_db", type="sql")

# Use the underlying SQLAlchemy session for writes
with conn.session as session:
    session.execute(
        text("INSERT INTO feedback (user_id, rating, comment) VALUES (:uid, :r, :c)"),
        params={"uid": user_id, "r": rating, "c": comment},
    )
    session.commit()

st.success("Feedback saved!")

# Invalidate related caches
get_feedback_summary.clear()
```

## See Also

- [Caching](../concepts/caching.md)
- [Data Dashboard](../patterns/data-dashboard.md)
- [Deployment](../patterns/deployment.md)
