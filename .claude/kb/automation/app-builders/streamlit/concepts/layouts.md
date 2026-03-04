# Layouts

> **Purpose**: Page structure with columns, tabs, sidebar, containers, and modal dialogs
> **Confidence**: HIGH (0.95)
> **MCP Validated**: 2026-03-03

## Overview

Streamlit provides layout components to organize content spatially on the page. Layouts use context managers (`with` blocks) to scope elements. Since version 1.46, layout components support unrestricted nesting (columns inside tabs inside expanders, etc.).

## The Pattern

```python
import streamlit as st

st.set_page_config(page_title="Dashboard", layout="wide")

# Sidebar
with st.sidebar:
    st.title("Filters")
    date_range = st.date_input("Date range")
    category = st.selectbox("Category", ["All", "A", "B"])

# Main content with columns
col1, col2, col3 = st.columns([2, 1, 1])
with col1:
    st.header("Chart")
    st.line_chart(data)
with col2:
    st.metric("Revenue", "$1.2M", "+12%")
with col3:
    st.metric("Orders", "4,521", "-3%")

# Tabs
tab1, tab2 = st.tabs(["Overview", "Details"])
with tab1:
    st.dataframe(summary_df)
with tab2:
    st.dataframe(detail_df)
```

## Quick Reference

| Component | Code | Use Case |
|-----------|------|----------|
| Sidebar | `with st.sidebar:` | Filters, navigation, settings |
| Columns | `cols = st.columns(3)` | Horizontal layout |
| Tabs | `tabs = st.tabs(["A", "B"])` | Tabbed sections |
| Expander | `with st.expander("More"):` | Collapsible content |
| Container | `with st.container():` | Grouping, border control |
| Empty | `slot = st.empty()` | Single-element placeholder |
| Popover | `with st.popover("Info"):` | Floating overlay |
| Dialog | `@st.dialog("Title")` | Modal overlay |

## Columns

```python
# Equal-width columns
c1, c2 = st.columns(2)

# Weighted columns
c1, c2, c3 = st.columns([3, 1, 1])

# With gap control
c1, c2 = st.columns(2, gap="large")  # "small", "medium", "large"

# Vertical alignment
c1, c2 = st.columns(2, vertical_alignment="center")  # "top", "center", "bottom"

# Usage
with c1:
    st.write("Left panel")
c2.metric("KPI", "42")  # alternative syntax
```

## Container Options

```python
with st.container(border=True):          # bordered section
    st.write("Content")
with st.container(height=300):           # fixed-height, scrollable
    for i in range(50): st.write(f"Line {i}")
placeholder = st.empty()                 # single-element placeholder
placeholder.text("Loading...")           # replaced on next call
with st.container(direction="horizontal", gap="medium"):  # flex row (1.48+)
    st.button("A")
    st.button("B")
```

## Top Navigation (1.46+)

```python
# Place navigation at the top instead of sidebar
pages = [
    st.Page("home.py", title="Home", icon=":material/home:"),
    st.Page("dashboard.py", title="Dashboard"),
]
pg = st.navigation(pages, position="top")
pg.run()
```

## Page Configuration

```python
st.set_page_config(
    page_title="My App",
    page_icon=":material/dashboard:",
    layout="wide",           # "centered" (default) or "wide"
    initial_sidebar_state="expanded",  # "auto", "expanded", "collapsed"
)

# Logo
st.logo("logo.png", link="https://example.com")
```

## Common Mistakes

### Wrong

```python
# Calling st.set_page_config after other Streamlit commands
st.title("Hello")
st.set_page_config(layout="wide")  # Error: must be first Streamlit command
```

### Correct

```python
# st.set_page_config must be the first Streamlit command
st.set_page_config(layout="wide")
st.title("Hello")
```

## Width Control (1.46+)

Most elements now accept a `width` parameter for sizing within flex containers:

```python
with st.container(direction="horizontal"):
    st.button("Small", width="small")
    st.button("Full", width="large")
```

## Related

- [Components](../concepts/components.md)
- [Data Dashboard](../patterns/data-dashboard.md)
- [Multi-Page Apps](../patterns/multi-page-apps.md)
