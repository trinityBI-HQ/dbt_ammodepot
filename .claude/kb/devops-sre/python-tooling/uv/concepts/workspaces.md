# Workspaces

> **Purpose**: Cargo-style workspaces for monorepo management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv workspaces manage multiple Python packages in a single repository with a shared lockfile. Inspired by Cargo, they enable consistent dependency resolution across all members while allowing each package to maintain its own `pyproject.toml`.

## The Pattern

```toml
# Root pyproject.toml
[project]
name = "my-platform"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["shared-lib"]

[tool.uv.workspace]
members = ["packages/*", "apps/*"]

[tool.uv.sources]
shared-lib = { workspace = true }
```

```
my-platform/
├── pyproject.toml          # Workspace root
├── uv.lock                 # Single shared lockfile
├── apps/
│   ├── api/
│   │   ├── pyproject.toml  # FastAPI app
│   │   └── src/api/
│   └── worker/
│       ├── pyproject.toml  # Background worker
│       └── src/worker/
└── packages/
    └── shared-lib/
        ├── pyproject.toml  # Shared library
        └── src/shared_lib/
```

## Workspace Commands

```bash
# Operations on workspace root (default)
uv sync                            # sync root + all members
uv lock                            # lock entire workspace

# Workspace introspection (v0.10+ stable)
uv workspace dir                   # print workspace root directory
uv workspace list                  # list all workspace members

# Target specific member
uv run --package api flask run
uv sync --package worker
uv add --package shared-lib pydantic

# Init new member inside workspace
cd packages && uv init new-lib --lib
```

## Member pyproject.toml

```toml
# apps/api/pyproject.toml
[project]
name = "api"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.100",
    "shared-lib",        # workspace dependency
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv.sources]
shared-lib = { workspace = true }
```

## Quick Reference

| Feature | Behavior |
|---------|----------|
| Lockfile | Single `uv.lock` at workspace root |
| Python version | Intersection of all members' `requires-python` |
| `uv run` | Operates on root by default |
| `uv run --package X` | Operates on specific member |
| `uv init` inside workspace | Auto-adds to workspace members |

## When to Use Workspaces

- Multiple related services sharing common libraries
- Monorepo with apps + shared packages
- Consistent dependency versions across packages

## When NOT to Use

- Packages with conflicting Python requirements
- Unrelated projects that happen to share a repo
- Single-package projects

## Common Mistakes

### Wrong

```toml
# Don't use path dependencies without workspace
[tool.uv.sources]
shared-lib = { path = "../packages/shared-lib" }
```

### Correct

```toml
# Use workspace = true for workspace members
[tool.uv.sources]
shared-lib = { workspace = true }
```

## Related

- [projects](projects.md)
- [../patterns/monorepo-workspaces](../patterns/monorepo-workspaces.md)
