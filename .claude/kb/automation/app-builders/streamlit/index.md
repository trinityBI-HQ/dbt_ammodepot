# Streamlit Knowledge Base

> **Purpose**: Python framework for building interactive data apps and dashboards with minimal code
> **MCP Validated**: 2026-03-03

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/components.md](concepts/components.md) | Widgets, input elements, media, and display elements |
| [concepts/state-management.md](concepts/state-management.md) | Session state, widget keys, callbacks, cross-page state |
| [concepts/caching.md](concepts/caching.md) | @st.cache_data, @st.cache_resource, TTL, invalidation |
| [concepts/layouts.md](concepts/layouts.md) | Columns, tabs, sidebar, containers, expanders, dialogs |
| [concepts/data-display.md](concepts/data-display.md) | Dataframes, charts, metrics, tables, JSON, code blocks |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/data-dashboard.md](patterns/data-dashboard.md) | Interactive dashboard with filters, charts, and KPIs |
| [patterns/form-handling.md](patterns/form-handling.md) | Forms, validation, st.dialog, and user input workflows |
| [patterns/multi-page-apps.md](patterns/multi-page-apps.md) | st.navigation + st.Page architecture, routing, shared state |
| [patterns/database-integration.md](patterns/database-integration.md) | st.connection, secrets.toml, SQL/Snowflake patterns |
| [patterns/llm-chat-app.md](patterns/llm-chat-app.md) | Chat UI with st.chat_message, st.chat_input, streaming |
| [patterns/deployment.md](patterns/deployment.md) | Community Cloud, Docker, production configuration |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for widgets, layouts, and commands

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Rerun model** | Every widget interaction reruns the entire script top-to-bottom |
| **Session state** | `st.session_state` persists data across reruns within a session |
| **Fragments** | `@st.fragment` reruns only a function instead of the full script |
| **Dialogs** | `@st.dialog` opens modal overlays with independent rerun scope |
| **Caching** | `@st.cache_data` (serializable) and `@st.cache_resource` (singletons) |
| **Connections** | `st.connection()` manages database/API connections with built-in caching |
| **Multipage** | `st.navigation` + `st.Page` for flexible multi-page routing |

---

## Installation

```bash
pip install streamlit          # pip
uv add streamlit               # uv
streamlit hello                # verify installation
streamlit run app.py           # run an app
streamlit init                 # scaffold a new project (1.44+)
```

---

## Getting Started

```python
import streamlit as st

st.title("My First App")
name = st.text_input("Your name")
if name:
    st.write(f"Hello, {name}!")
```

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/components.md, concepts/layouts.md |
| **Intermediate** | concepts/state-management.md, concepts/caching.md, patterns/form-handling.md |
| **Advanced** | patterns/multi-page-apps.md, patterns/database-integration.md, patterns/llm-chat-app.md |

---

## Cross-References

| Related KB | Relevance |
|------------|-----------|
| [Snowflake KB](../../data-engineering/data-platforms/snowflake/) | SnowflakeConnection, Streamlit in Snowflake |
| [Pydantic KB](../../ai-ml/validation/pydantic/) | Form validation patterns |
| [Docker Compose KB](../../devops-sre/containerization/docker-compose/) | Container deployment |

**Current version**: 1.54.x (Feb 2026). Key milestones: st.connection (1.28), st.cache_data/resource (1.18), st.fragment (1.33), st.dialog (1.35), native multipage (1.36), st.login/logout (1.42), st.badge (1.44).
