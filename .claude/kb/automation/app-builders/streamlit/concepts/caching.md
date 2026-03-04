# Caching

> **Purpose**: @st.cache_data and @st.cache_resource for performance optimization
> **Confidence**: HIGH (0.95)
> **MCP Validated**: 2026-03-03

## Overview

Streamlit provides two caching decorators to prevent redundant computation across reruns. `@st.cache_data` caches serializable return values (DataFrames, dicts, strings) by creating copies. `@st.cache_resource` caches global singletons (ML models, DB connections) without copying. Both use function name + arguments as cache keys.

## The Pattern

```python
import streamlit as st
import pandas as pd

# Cache serializable data -- returns a COPY each time
@st.cache_data(ttl=3600)
def load_data(path: str) -> pd.DataFrame:
    return pd.read_csv(path)

# Cache global resources -- returns the SAME object
@st.cache_resource
def get_model():
    from transformers import pipeline
    return pipeline("sentiment-analysis")

# Usage
df = load_data("sales.csv")    # cached for 1 hour
model = get_model()            # singleton across all sessions
```

## Quick Reference

| Feature | `@st.cache_data` | `@st.cache_resource` |
|---------|-------------------|----------------------|
| Returns | Copy of cached value | Same object (singleton) |
| Best for | DataFrames, dicts, lists, strings | ML models, DB connections |
| Thread-safe | Yes (copies) | No (shared mutation risk) |
| Serialization | pickle | None |
| Memory | Higher (copies per call) | Lower (one instance) |
| TTL support | Yes | Yes |
| max_entries | Yes | Yes |

## Parameters

```python
@st.cache_data(
    ttl=3600,                    # seconds or timedelta; None = forever
    max_entries=100,             # max cached results; oldest evicted
    show_spinner=True,           # True, False, or "Loading..." string
    hash_funcs={MyClass: hash},  # custom hash for unhashable args
    experimental_allow_widgets=False,  # allow widgets inside
)
def my_function(arg1, arg2):
    ...
```

## Excluding Parameters from Cache Key

```python
# Prefix with underscore to exclude from hashing
@st.cache_data
def query_db(_conn, sql: str) -> pd.DataFrame:
    return pd.read_sql(sql, _conn)  # _conn not part of cache key

# Only `sql` determines cache hits
df1 = query_db(conn, "SELECT * FROM users")
df2 = query_db(conn, "SELECT * FROM users")  # cache hit
```

## Cache Invalidation

```python
# Clear all entries for a specific function
load_data.clear()

# Clear ALL caches globally
st.cache_data.clear()
st.cache_resource.clear()

# Time-based expiry
@st.cache_data(ttl=datetime.timedelta(hours=1))
def fetch_api_data():
    return requests.get("https://api.example.com/data").json()
```

## Common Mistakes

### Wrong

```python
# Mutating cached data -- modifies the shared original
@st.cache_resource
def get_dataframe():
    return pd.DataFrame({"a": [1, 2, 3]})

df = get_dataframe()
df["b"] = [4, 5, 6]  # mutates cached object for ALL users
```

### Correct

```python
# Use cache_data for mutable data -- each call gets a copy
@st.cache_data
def get_dataframe():
    return pd.DataFrame({"a": [1, 2, 3]})

df = get_dataframe()
df["b"] = [4, 5, 6]  # safe: modifying a copy
```

## Performance Note

For datasets exceeding 100M rows, prefer `@st.cache_resource` (returns in ~0s) over `@st.cache_data` (serialization adds 2-7s). Treat the returned object as read-only.

## Session-Scoped Caching (1.53+)

```python
# Per-session caching (not shared across users)
@st.cache_data(scope="session")
def get_user_preferences():
    return load_preferences(st.session_state.user_id)

@st.cache_resource(scope="session")
def get_user_connection():
    return create_connection(st.session_state.user_id)
```

## Static Elements in Cached Functions

Streamlit commands inside cached functions replay on cache hits:

```python
@st.cache_data
def load_and_report(path):
    df = pd.read_csv(path)
    st.success(f"Loaded {len(df)} rows")  # replays from cache
    return df
```

## Related

- [State Management](../concepts/state-management.md)
- [Database Integration](../patterns/database-integration.md)
- [Data Dashboard](../patterns/data-dashboard.md)
