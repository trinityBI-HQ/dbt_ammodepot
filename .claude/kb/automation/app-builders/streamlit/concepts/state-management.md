# State Management

> **Purpose**: Session state, widget keys, callbacks, and cross-page state persistence
> **Confidence**: HIGH (0.95)
> **MCP Validated**: 2026-03-03

## Overview

Streamlit reruns the entire script on every user interaction. `st.session_state` is a per-session dictionary that persists values across reruns. It is the primary mechanism for maintaining application state, sharing data between pages, and controlling widget behavior.

## The Pattern

```python
import streamlit as st

# Initialize state (runs only on first load)
if "counter" not in st.session_state:
    st.session_state.counter = 0

# Read state
st.write(f"Count: {st.session_state.counter}")

# Modify state via button callback
def increment():
    st.session_state.counter += 1

st.button("Increment", on_click=increment)

# Access via dict or attribute syntax
st.session_state["counter"]    # dict-style
st.session_state.counter       # attribute-style
```

## Widget-State Binding

```python
# Bind widget value to session_state via key parameter
st.text_input("Name", key="user_name")

# The widget value is now accessible as:
current_name = st.session_state.user_name

# Callbacks receive state automatically
def on_name_change():
    st.session_state.greeting = f"Hello, {st.session_state.user_name}!"

st.text_input("Name", key="user_name", on_change=on_name_change)
```

## Quick Reference

| Operation | Code | Notes |
|-----------|------|-------|
| Initialize | `if "k" not in st.session_state: st.session_state.k = val` | Guard against reset |
| Read | `st.session_state.k` or `st.session_state["k"]` | Both work |
| Write | `st.session_state.k = val` | Triggers no rerun |
| Delete | `del st.session_state.k` | Removes key |
| Check | `"k" in st.session_state` | Boolean check |
| Iterate | `for k, v in st.session_state.items()` | Dict-like iteration |

## Callbacks

```python
# on_click for buttons
def handle_submit():
    st.session_state.submitted = True
    st.session_state.data = process(st.session_state.form_input)

st.button("Submit", on_click=handle_submit)

# on_change for input widgets
def handle_filter_change():
    st.session_state.filtered_df = df[df["col"] == st.session_state.filter_val]

st.selectbox("Filter", options, key="filter_val", on_change=handle_filter_change)

# Callbacks with arguments
def handle_delete(item_id):
    st.session_state.items.remove(item_id)

st.button("Delete", on_click=handle_delete, args=(item_id,))
```

## Cross-Page State

```python
# Page 1: Set state
st.session_state.selected_customer_id = 42

# Page 2: Read state (same session)
customer_id = st.session_state.get("selected_customer_id")
if customer_id:
    st.write(f"Viewing customer {customer_id}")
else:
    st.warning("No customer selected. Go to Page 1.")
```

**Important**: Navigating between pages by clicking URL links resets `st.session_state`. Always use `st.switch_page()`, `st.page_link()`, or built-in navigation to preserve state.

## Common Mistakes

### Wrong

```python
# Setting widget value directly -- raises StreamlitAPIException
st.session_state.my_slider = 50
st.slider("Value", 0, 100, key="my_slider")  # Error: cannot set default after key exists
```

### Correct

```python
# Initialize before widget, or use only the key binding
if "my_slider" not in st.session_state:
    st.session_state.my_slider = 50
st.slider("Value", 0, 100, key="my_slider")
```

## Fragment and Dialog State

Fragments and dialogs share the same `st.session_state` as the main script. Use session state to communicate between fragments and the rest of the app.

```python
@st.fragment
def filter_panel():
    st.selectbox("Category", ["A", "B"], key="category")
    # st.session_state.category is accessible in main script

@st.dialog("Edit Item")
def edit_dialog(item_id):
    new_name = st.text_input("Name", value=st.session_state.items[item_id])
    if st.button("Save"):
        st.session_state.items[item_id] = new_name
        st.rerun()
```

## Related

- [Components](../concepts/components.md)
- [Caching](../concepts/caching.md)
- [Multi-Page Apps](../patterns/multi-page-apps.md)
