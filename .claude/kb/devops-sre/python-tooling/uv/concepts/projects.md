# Projects

> **Purpose**: Project structure, initialization, and pyproject.toml management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv manages Python projects centered around `pyproject.toml`. It creates virtual environments and lockfiles automatically. Projects can be applications, packaged apps, or libraries, each with appropriate directory layouts.

## The Pattern

```bash
# Create application (default)
uv init my-app
# Creates: main.py, pyproject.toml, README.md, .python-version, .gitignore

# Create packaged application (for PyPI distribution, CLI tools)
uv init --package my-cli
# Creates: src/my_cli/__init__.py, pyproject.toml with [build-system]

# Create library
uv init --lib my-lib
# Creates: src/my_lib/__init__.py, py.typed, pyproject.toml

# Create minimal (just pyproject.toml)
uv init --bare my-project

# Run project
uv run python main.py
uv run my-cli          # if [project.scripts] defined
```

## Project Structure

```
my-app/
├── .venv/              # Auto-created virtual environment
├── .python-version     # Pinned Python version
├── .gitignore
├── README.md
├── main.py             # Entry point (apps)
├── pyproject.toml      # Project metadata + dependencies
└── uv.lock             # Cross-platform lockfile
```

## pyproject.toml Anatomy

```toml
[project]
name = "my-app"
version = "0.1.0"
description = "My application"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.100",
    "httpx",
]

[project.scripts]
my-app = "my_app:main"     # CLI entry point

[dependency-groups]
dev = ["pytest>=8.0", "ruff"]
lint = ["mypy"]

[build-system]                # Only for packaged projects
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv]
python-preference = "managed"
```

## Quick Reference

| File | Purpose | Committed to Git |
|------|---------|-----------------|
| `pyproject.toml` | Project metadata, deps | Yes |
| `uv.lock` | Exact dependency versions | Yes |
| `.python-version` | Python version pin | Yes |
| `.venv/` | Virtual environment | No |

## Common Mistakes

### Wrong

```bash
# Don't manually create venvs
python -m venv .venv
pip install -r requirements.txt
```

### Correct

```bash
# Let uv manage everything
uv init my-project
uv add requests flask
uv run python main.py
```

## Related

- [dependencies](dependencies.md)
- [workspaces](workspaces.md)
