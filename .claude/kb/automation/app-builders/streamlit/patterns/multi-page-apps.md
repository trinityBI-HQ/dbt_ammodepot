# Multi-Page App Pattern

> **Purpose**: Build multi-page apps with st.navigation, st.Page, and shared state
> **MCP Validated**: 2026-03-03

## When to Use

- Applications with 3+ distinct sections or views
- Apps requiring shared navigation, sidebar, and branding
- Separating concerns (data entry, reporting, admin) into pages
- Building internal tools with role-based page visibility

## Implementation

```python
# app.py -- entrypoint
import streamlit as st

st.set_page_config(page_title="My App", layout="wide")

# Define pages from files or callables
pages = [
    st.Page("pages/home.py", title="Home", icon=":material/home:", default=True),
    st.Page("pages/dashboard.py", title="Dashboard", icon=":material/bar_chart:"),
    st.Page("pages/settings.py", title="Settings", icon=":material/settings:"),
]

# Create navigation (sidebar by default)
pg = st.navigation(pages)

# Shared elements rendered on ALL pages
st.logo("logo.png")
st.sidebar.markdown("---")
st.sidebar.caption("v1.0.0")

# Run the selected page
pg.run()
```

```python
# pages/home.py
import streamlit as st

st.title("Home")
st.write("Welcome to the application.")

if st.button("Go to Dashboard"):
    st.switch_page("pages/dashboard.py")
```

```python
# pages/dashboard.py
import streamlit as st
import pandas as pd

st.title("Dashboard")
# Access shared state set on other pages
if "selected_date" in st.session_state:
    st.info(f"Showing data for {st.session_state.selected_date}")

df = load_data()
st.dataframe(df)
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `position` | `"sidebar"` | `"sidebar"` or `"top"` (1.46+) |
| `default` | `False` | Mark one page as the landing page |
| `icon` | `None` | Material icon or emoji |
| `url_path` | auto from filename | Custom URL path segment |

## Grouped Navigation

```python
# Organize pages into sections
pages = {
    "Main": [
        st.Page("pages/home.py", title="Home"),
        st.Page("pages/dashboard.py", title="Dashboard"),
    ],
    "Admin": [
        st.Page("pages/users.py", title="Users"),
        st.Page("pages/settings.py", title="Settings"),
    ],
}

pg = st.navigation(pages)
pg.run()
```

## Top Navigation (1.46+)

```python
pg = st.navigation(pages, position="top")
pg.run()
```

## Pages as Callables

```python
def home_page():
    st.title("Home")
    st.write("Welcome!")

def about_page():
    st.title("About")
    st.write("This app does X, Y, Z.")

pages = [
    st.Page(home_page, title="Home", default=True),
    st.Page(about_page, title="About"),
]

pg = st.navigation(pages)
pg.run()
```

## Conditional Pages (Role-Based)

```python
# Show admin pages only for authenticated admins
base_pages = [
    st.Page("pages/home.py", title="Home", default=True),
    st.Page("pages/dashboard.py", title="Dashboard"),
]

admin_pages = [
    st.Page("pages/admin.py", title="Admin Panel"),
    st.Page("pages/settings.py", title="Settings"),
]

if st.session_state.get("is_admin", False):
    pages = {"Main": base_pages, "Admin": admin_pages}
else:
    pages = base_pages

pg = st.navigation(pages)
pg.run()
```

## Cross-Page Navigation

```python
# Programmatic navigation (preserves session_state)
st.switch_page("pages/dashboard.py")

# Navigation links (preserves session_state)
st.page_link("pages/dashboard.py", label="View Dashboard", icon=":material/bar_chart:")

# Query parameters in navigation (1.52+)
st.switch_page("pages/detail.py?id=42")
```

## Directory Structure

```text
my_app/
├── app.py                  # entrypoint with st.navigation
├── pages/
│   ├── home.py
│   ├── dashboard.py
│   ├── settings.py
│   └── admin.py
├── components/             # shared UI components
│   └── filters.py
├── utils/                  # data loading, helpers
│   └── data.py
├── .streamlit/
│   ├── config.toml         # app configuration
│   └── secrets.toml        # credentials
└── requirements.txt
```

## Common Mistake

**Wrong**: Using URL links (`st.markdown("[Page](./page)")`) to navigate -- this creates a new browser session and resets `st.session_state`.

**Correct**: Use `st.switch_page()`, `st.page_link()`, or the built-in navigation menu to preserve session state across pages.

## See Also

- [State Management](../concepts/state-management.md)
- [Layouts](../concepts/layouts.md)
- [Deployment](../patterns/deployment.md)
