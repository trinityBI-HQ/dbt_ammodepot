# uv Knowledge Base

> **Purpose**: Ultra-fast Python package and project manager by Astral, written in Rust
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/installation.md](concepts/installation.md) | Installing uv and getting started |
| [concepts/projects.md](concepts/projects.md) | Project structure, init, pyproject.toml |
| [concepts/dependencies.md](concepts/dependencies.md) | Dependency management, lockfile, sync |
| [concepts/python-management.md](concepts/python-management.md) | Installing and managing Python versions |
| [concepts/scripts-tools.md](concepts/scripts-tools.md) | Running scripts, inline metadata, tool management |
| [concepts/workspaces.md](concepts/workspaces.md) | Cargo-style workspaces for monorepos |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/migration-from-pip.md](patterns/migration-from-pip.md) | Migrating from pip/poetry/pipenv to uv |
| [patterns/docker-integration.md](patterns/docker-integration.md) | Optimized Dockerfiles with uv |
| [patterns/ci-cd-integration.md](patterns/ci-cd-integration.md) | GitHub Actions, caching, CI/CD workflows |
| [patterns/monorepo-workspaces.md](patterns/monorepo-workspaces.md) | Workspace patterns for large projects |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Unified Toolchain** | Replaces pip, pip-tools, pipx, poetry, pyenv, virtualenv, twine |
| **Universal Lockfile** | Cross-platform `uv.lock` for reproducible environments |
| **Global Cache** | Disk-space efficient deduplication across projects |
| **Inline Script Metadata** | PEP 723 dependencies declared directly in .py files |
| **Workspaces** | Cargo-style monorepo support with shared lockfile |
| **Publishing** | `uv publish` for PyPI publishing (v0.7+) |
| **Python Upgrade** | `uv python upgrade` for in-place version upgrades (v0.10+) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/installation.md, concepts/projects.md |
| **Intermediate** | concepts/dependencies.md, concepts/scripts-tools.md |
| **Advanced** | concepts/workspaces.md, patterns/docker-integration.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| python-developer | All concepts + patterns | Python project setup and management |
| ci-cd-specialist | patterns/ci-cd-integration.md | CI/CD pipeline configuration |
| infra-deployer | patterns/docker-integration.md | Container deployment |

---

## Breaking Changes (v0.8 - v0.10)

| Version | Breaking Change | Migration |
|---------|----------------|-----------|
| v0.8 | `uv python install` installs versioned executables to `~/.local/bin` by default | Set `UV_PYTHON_INSTALL_DIR` to override |
| v0.10 | `uv venv` requires `--clear` to remove existing venvs | Add `--clear` flag explicitly |
| v0.10 | Error if multiple indexes have `default = true` | Keep only one default index |
| v0.10 | Error when explicit index is unnamed | Add `name` to all `[[tool.uv.index]]` entries |
