# Dependencies

> **Purpose**: Dependency management, lockfile, syncing environments
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv provides fast, deterministic dependency management through `uv.lock` (universal lockfile) and automatic environment syncing. Dependencies are declared in `pyproject.toml` and resolved across all platforms in a single lockfile.

## The Pattern

```bash
# Add dependencies
uv add requests                    # latest version
uv add "fastapi>=0.100,<1.0"      # version constraints
uv add httpx --optional api        # optional extra

# Add dev/group dependencies
uv add --dev pytest ruff           # dev group
uv add --group lint mypy           # named group

# Remove dependencies
uv remove requests

# Lock and sync
uv lock                            # resolve and write uv.lock
uv sync                            # install from lockfile
uv sync --locked                   # fail if lockfile out of date
uv sync --frozen                   # don't update lockfile
uv sync --no-dev                   # production only

# Inspect
uv tree                            # dependency tree
uv tree --outdated                 # show outdated packages

# Upgrade
uv lock --upgrade                  # upgrade all
uv lock --upgrade-package requests # upgrade specific package
```

## Lockfile (uv.lock)

The universal lockfile captures exact versions for all platforms:
- Cross-platform: works on macOS, Linux, Windows
- Deterministic: same input always produces same output
- Human-readable: TOML format (but don't edit manually)
- Commit to Git: ensures reproducible builds

## Quick Reference

| Action | Command | Notes |
|--------|---------|-------|
| Add prod dep | `uv add <pkg>` | Updates pyproject.toml + uv.lock |
| Add dev dep | `uv add --dev <pkg>` | Goes into [dependency-groups] dev |
| Add group dep | `uv add --group <name> <pkg>` | Custom dependency group |
| Remove dep | `uv remove <pkg>` | Cleans lockfile too |
| Sync env | `uv sync` | Installs/removes to match lockfile |
| CI install | `uv sync --locked --no-dev` | Strict, production only |
| Upgrade all | `uv lock --upgrade` | Resolves latest versions |
| Show tree | `uv tree` | Full dependency graph |

## Version Specifiers

```toml
dependencies = [
    "requests>=2.28",           # minimum version
    "flask>=3.0,<4.0",          # range
    "numpy~=1.26.0",            # compatible release (~= 1.26.x)
    "pandas==2.2.0",            # exact pin (avoid in libraries)
]
```

## Common Mistakes

### Wrong

```bash
# Don't install packages directly into the venv
.venv/bin/pip install requests
```

### Correct

```bash
# Always go through uv for tracking
uv add requests
```

## Index Configuration (v0.10 Breaking Changes)

```toml
# pyproject.toml -- named indexes required in v0.10+
[[tool.uv.index]]
name = "pytorch"
url = "https://download.pytorch.org/whl/cpu"

[[tool.uv.index]]
name = "pypi"
url = "https://pypi.org/simple"
default = true          # Only ONE index can be default
```

Starting with v0.10, explicit indexes must have a `name` field, and only one index can set `default = true`. Violating either rule now raises an error instead of a warning.

## Related

- [projects](projects.md)
- [../patterns/migration-from-pip](../patterns/migration-from-pip.md)
