# Python Management

> **Purpose**: Installing and managing Python versions with uv
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv can install, manage, and switch between Python versions without pyenv or system package managers. It downloads pre-built Python distributions and manages them in a central location, automatically selecting the right version per project.

## The Pattern

```bash
# Install Python versions
uv python install 3.12           # install specific version
uv python install 3.11 3.12 3.13 # install multiple
uv python install                 # install version from .python-version

# Upgrade Python to latest patch (v0.10+ stable)
uv python upgrade                 # upgrade pinned version to latest patch
uv python upgrade 3.12            # upgrade 3.12.x to latest 3.12 patch

# List versions
uv python list                    # all available
uv python list --installed-only   # only installed

# Find installed version
uv python find 3.12               # path to Python 3.12

# Pin project to a version
uv python pin 3.12                # writes .python-version file

# Uninstall
uv python uninstall 3.11
```

## How Version Selection Works

1. Project has `.python-version` file → uses that version
2. `pyproject.toml` has `requires-python` → finds compatible version
3. Falls back to system Python if compatible
4. Auto-downloads if `python-preference = "managed"`

## Quick Reference

| Preference | Behavior |
|-----------|----------|
| `managed` | Prefer uv-managed Python, download if needed |
| `system` | Prefer system Python, fall back to managed |
| `only-managed` | Only use uv-managed Python |
| `only-system` | Only use system Python, never download |

```toml
# pyproject.toml
[tool.uv]
python-preference = "managed"
```

## Versioned Executables (v0.8+)

Starting with v0.8, `uv python install` places versioned executables (e.g., `python3.12`) directly into `~/.local/bin` by default. This means installed Python versions are immediately available on PATH without activating a virtual environment. On Windows, versions are registered via PEP 514 (Windows Registry).

```bash
# After uv python install 3.12:
which python3.12              # ~/.local/bin/python3.12
python3.12 --version          # Python 3.12.x
```

## .python-version File

```
3.12
```

This file is read by uv (and other tools like pyenv) to determine the project's Python version. Created by `uv python pin` or `uv init`.

## Common Mistakes

### Wrong

```bash
# Don't use pyenv alongside uv for version management
pyenv install 3.12.0
pyenv local 3.12.0
uv sync  # may pick wrong Python
```

### Correct

```bash
# Let uv handle Python versions
uv python install 3.12
uv python pin 3.12
uv sync  # uses pinned version
```

## Related

- [installation](installation.md)
- [projects](projects.md)
