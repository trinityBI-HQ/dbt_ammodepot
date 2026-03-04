# Streamlit Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-03-03

## Core Widgets

| Widget | Code | Returns |
|--------|------|---------|
| Button | `st.button("Click")` | `bool` |
| Text input | `st.text_input("Label")` | `str` |
| Number input | `st.number_input("Label")` | `int/float` |
| Slider | `st.slider("Label", 0, 100)` | `int/float` |
| Selectbox | `st.selectbox("Pick", options)` | selected value |
| Multiselect | `st.multiselect("Pick", options)` | `list` |
| Checkbox | `st.checkbox("Check")` | `bool` |
| Date input | `st.date_input("Date")` | `date` |
| File uploader | `st.file_uploader("File")` | `UploadedFile/None` |
| Chat input | `st.chat_input("Message")` | `str/None` |

## Display Elements

| Element | Code | Use Case |
|---------|------|----------|
| Text | `st.write(obj)` | Auto-formats any object |
| Markdown | `st.markdown("**bold**")` | Rich text |
| Title | `st.title("Header")` | Page title (h1) |
| Metric | `st.metric("Revenue", "$1M", "+5%")` | KPI cards |
| DataFrame | `st.dataframe(df)` | Interactive table |
| Table | `st.table(df)` | Static table |
| JSON | `st.json(data)` | Collapsible JSON |
| Code | `st.code(code, language="python")` | Syntax-highlighted |
| Badge | `st.badge("Active", color="green")` | Status labels |

## Layout Elements

| Layout | Code | Notes |
|--------|------|-------|
| Sidebar | `st.sidebar.write("Side")` | Persistent side panel |
| Columns | `c1, c2 = st.columns(2)` | Horizontal layout |
| Tabs | `t1, t2 = st.tabs(["A", "B"])` | Tabbed sections |
| Expander | `st.expander("More")` | Collapsible section |
| Container | `st.container()` | Grouping element |
| Empty | `st.empty()` | Single-element placeholder |
| Popover | `st.popover("Info")` | Floating overlay |

## Caching Decision Matrix

| Use Case | Decorator | Why |
|----------|-----------|-----|
| DataFrame from CSV/SQL | `@st.cache_data` | Returns copy, safe |
| API response (dict/list) | `@st.cache_data` | Serializable data |
| ML model loading | `@st.cache_resource` | Singleton, not copied |
| DB connection object | `@st.cache_resource` | Unserializable resource |
| Large dataset (100M+ rows) | `@st.cache_resource` | Avoids serialize cost |

## Execution Flow

| Decorator | Behavior | Scope |
|-----------|----------|-------|
| `@st.fragment` | Rerun only this function | Widget interactions inside |
| `@st.dialog("Title")` | Modal overlay, independent rerun | One dialog at a time |
| `@st.cache_data(ttl=3600)` | Cache serializable return values | All sessions |
| `@st.cache_resource` | Cache singleton resources | All sessions |

## CLI Commands

| Command | Purpose |
|---------|---------|
| `streamlit run app.py` | Run app locally |
| `streamlit run app.py --server.port 8080` | Custom port |
| `streamlit init` | Scaffold new project |
| `streamlit hello` | Demo app |
| `streamlit config show` | Show all config |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Mutate `@st.cache_data` return values | Return new objects or use `@st.cache_resource` |
| Store widgets in `st.session_state` directly | Store widget values via `key` parameter |
| Use `st.cache` (deprecated) | Use `@st.cache_data` or `@st.cache_resource` |
| Navigate between pages via URL links | Use `st.switch_page()` or `st.page_link()` |
| Put `st.sidebar` inside `@st.dialog` | Use dialog body only; no sidebar access |
| Call multiple `@st.dialog` functions per run | Only one dialog can be open at a time |

## Related Documentation

| Topic | Path |
|-------|------|
| Components & widgets | `concepts/components.md` |
| State management | `concepts/state-management.md` |
| Caching deep dive | `concepts/caching.md` |
| Full index | `index.md` |
