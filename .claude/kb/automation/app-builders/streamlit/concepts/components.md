# Components and Widgets

> **Purpose**: Core input widgets, display elements, media, and status indicators
> **Confidence**: HIGH (0.95)
> **MCP Validated**: 2026-03-03

## Overview

Streamlit provides 40+ built-in components for user interaction and data display. Every widget returns a value and triggers a full script rerun when the user interacts with it. Widgets are identified by their `key` parameter (or auto-generated key from label and position).

## Input Widgets

```python
import streamlit as st

# Text inputs
name = st.text_input("Name", placeholder="Enter name")
bio = st.text_area("Bio", max_chars=500)
password = st.text_input("Password", type="password")

# Numeric inputs
age = st.number_input("Age", min_value=0, max_value=120, step=1)
rating = st.slider("Rating", 0.0, 5.0, 2.5, step=0.5)

# Selection inputs
color = st.selectbox("Color", ["Red", "Blue", "Green"])
tags = st.multiselect("Tags", ["Python", "Data", "ML"])
agreed = st.checkbox("I agree")
size = st.radio("Size", ["S", "M", "L"], horizontal=True)
priority = st.select_slider("Priority", ["Low", "Medium", "High"])

# Date/time inputs
date = st.date_input("Start date")
time = st.time_input("Meeting time")
dt = st.datetime_input("Event datetime")  # 1.52+

# File inputs
file = st.file_uploader("Upload CSV", type=["csv", "xlsx"])
files = st.file_uploader("Uploads", accept_multiple_files=True)

# Action widgets
clicked = st.button("Submit", type="primary")
st.download_button("Download", data=csv_data, file_name="data.csv")
st.link_button("Docs", "https://docs.streamlit.io")
feedback = st.feedback("thumbs")  # thumbs up/down
```

## Quick Reference

| Category | Widgets | Key Parameter |
|----------|---------|---------------|
| Text | `text_input`, `text_area` | `placeholder`, `max_chars` |
| Numeric | `number_input`, `slider` | `min_value`, `max_value`, `step` |
| Selection | `selectbox`, `multiselect`, `radio`, `select_slider` | `options`, `index` |
| Boolean | `checkbox`, `toggle` | `value` (default) |
| Date/Time | `date_input`, `time_input`, `datetime_input` | `value`, `min_value`, `max_value` |
| File | `file_uploader`, `camera_input` | `type`, `accept_multiple_files` |
| Action | `button`, `download_button`, `link_button`, `form_submit_button` | `type`, `on_click` |

## Display Elements

```python
# Text
st.title("Page Title")           # h1
st.header("Section")             # h2
st.subheader("Subsection")       # h3
st.markdown("**bold** _italic_") # GitHub-flavored Markdown
st.write(any_object)             # auto-detects type
st.caption("Small gray text")
st.divider()                     # horizontal rule
st.badge("Active", color="green")  # 1.44+

# Status
st.success("Done!")
st.info("FYI")
st.warning("Careful!")
st.error("Failed!")
st.exception(RuntimeError("Details"))
st.toast("Notification!", icon="check")

# Media
st.image("photo.png", caption="Photo", width=300)
st.audio("audio.mp3")
st.video("video.mp4")
```

## Common Mistakes

### Wrong

```python
# Widget without key -- fragile if you reorder widgets
name = st.text_input("Name")
email = st.text_input("Email")
```

### Correct

```python
# Explicit keys for stable widget identity
name = st.text_input("Name", key="user_name")
email = st.text_input("Email", key="user_email")
```

## Widget Key Rules (1.50+)

Since Streamlit 1.50, widget identity is based solely on the `key` parameter. This means changing a widget's label, options, or other parameters will not reset its value as long as the key remains the same. Always use explicit keys for widgets that must persist values across code changes.

## Related

- [State Management](../concepts/state-management.md)
- [Layouts](../concepts/layouts.md)
- [Form Handling](../patterns/form-handling.md)
