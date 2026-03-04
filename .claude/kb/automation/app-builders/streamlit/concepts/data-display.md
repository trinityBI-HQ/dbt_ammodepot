# Data Display

> **Purpose**: DataFrames, charts, metrics, tables, and visualization elements
> **Confidence**: HIGH (0.95)
> **MCP Validated**: 2026-03-03

## Overview

Streamlit provides native support for displaying data through interactive DataFrames, built-in charts (powered by Vega-Lite/Altair), metrics with deltas, and integration with external libraries like Plotly and Matplotlib. DataFrames default to `use_container_width=True` since 1.43.

## The Pattern

```python
import streamlit as st
import pandas as pd

# Interactive DataFrame with search, sort, filter
st.dataframe(df, use_container_width=True, hide_index=True)

# Editable DataFrame
edited_df = st.data_editor(
    df,
    num_rows="dynamic",       # allow adding/deleting rows
    column_config={
        "price": st.column_config.NumberColumn("Price", format="$%.2f"),
        "rating": st.column_config.ProgressColumn("Rating", max_value=5),
        "status": st.column_config.SelectboxColumn("Status", options=["Active", "Inactive"]),
    },
)

# Metrics with delta indicators
col1, col2, col3 = st.columns(3)
col1.metric("Revenue", "$1.2M", "+12%")
col2.metric("Users", "8,432", "-2%", delta_color="inverse")
col3.metric("Uptime", "99.9%", "0.1%")
```

## Quick Reference

| Element | Code | Interactive |
|---------|------|-------------|
| DataFrame | `st.dataframe(df)` | Sort, search, resize |
| Data Editor | `st.data_editor(df)` | Edit, add, delete rows |
| Static Table | `st.table(df)` | No interaction |
| Metric | `st.metric(label, value, delta)` | Display only |
| JSON | `st.json(data)` | Expand/collapse |
| Code | `st.code(code, language="sql")` | Copy button |

## Column Configuration

```python
st.data_editor(df, column_config={
    "revenue": st.column_config.NumberColumn("Revenue", format="$%d"),
    "completion": st.column_config.ProgressColumn("Done", max_value=100),
    "url": st.column_config.LinkColumn("Website"),
    "avatar": st.column_config.ImageColumn("Photo", width="small"),
    "status": st.column_config.SelectboxColumn("Status", options=["Draft", "Published"]),
    "active": st.column_config.CheckboxColumn("Active", default=True),
    "created": st.column_config.DateColumn("Created", format="YYYY-MM-DD"),
    "tags": st.column_config.ListColumn("Tags"),
    "metadata": st.column_config.JsonColumn("Meta"),  # 1.43+
})
```

## Built-in Charts

```python
# Line chart
st.line_chart(df, x="date", y=["sales", "profit"], color=["#ff0000", "#0000ff"])

# Bar chart
st.bar_chart(df, x="category", y="count")

# Area chart
st.area_chart(df, x="date", y="value")

# Scatter chart
st.scatter_chart(df, x="weight", y="height", color="species", size="count")

# Map (requires lat/lon columns)
st.map(df)  # expects "lat" and "lon" columns
```

## External Chart Libraries

```python
import plotly.express as px
import altair as alt
import matplotlib.pyplot as plt

# Plotly
fig = px.bar(df, x="category", y="value", color="group")
st.plotly_chart(fig, use_container_width=True)

# Altair
chart = alt.Chart(df).mark_bar().encode(x="category", y="value")
st.altair_chart(chart, use_container_width=True)

# Matplotlib
fig, ax = plt.subplots()
ax.plot(df["x"], df["y"])
st.pyplot(fig)
```

## Additional Features (1.49+)

```python
# Cell selection -- returns selected rows/columns on interaction
event = st.dataframe(df, on_select="rerun", selection_mode=["multi-row"])
selected_rows = event.selection.rows

# PDF rendering
st.pdf("document.pdf")  # renders PDF inline
```

## Common Mistakes

### Wrong

```python
# Using st.table for large datasets -- renders entire table, no pagination
st.table(large_df)  # slow with 10K+ rows
```

### Correct

```python
# Use st.dataframe for large datasets -- virtualized rendering
st.dataframe(large_df)  # handles millions of rows efficiently
```

## Related

- [Layouts](../concepts/layouts.md)
- [Data Dashboard](../patterns/data-dashboard.md)
- [Database Integration](../patterns/database-integration.md)
