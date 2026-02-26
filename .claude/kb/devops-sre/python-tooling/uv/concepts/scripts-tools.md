# Scripts & Tools

> **Purpose**: Running scripts with inline dependencies and managing CLI tools
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv supports two powerful workflows: running standalone scripts with PEP 723 inline dependency metadata, and installing/running Python CLI tools (like ruff, black, mypy) in isolated environments. Scripts get auto-provisioned environments; tools replace pipx.

## Scripts with Inline Metadata (PEP 723)

```python
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "httpx",
#   "rich",
# ]
# ///

import httpx
from rich import print

resp = httpx.get("https://api.github.com/repos/astral-sh/uv")
print(resp.json()["stargazers_count"])
```

```bash
# Run the script - uv auto-creates isolated env
uv run example.py

# Add dependency to existing script
uv add --script example.py pandas

# Remove dependency from script
uv remove --script example.py pandas

# Make script executable (Unix)
#!/usr/bin/env -S uv run --script
```

## Ephemeral Dependencies with --with (v0.8+)

```bash
# Add temporary packages to the run environment without modifying pyproject.toml
uv run --with rich script.py              # add rich for this run only
uv run --with "pandas>=2.0" analysis.py   # version constraints supported
uv run --with rich --with httpx app.py    # multiple ephemeral deps

# Combine with scripts that have inline metadata
uv run --with debugpy my_script.py        # overlay extra deps on PEP 723 script
```

The `--with` flag creates an ephemeral environment layered on top of the project environment. Packages added with `--with` are not written to `pyproject.toml` or `uv.lock`.

## Tool Management (replaces pipx)

```bash
# Run tool without installing (temporary env)
uvx ruff check .
uvx black --check src/
uvx mypy src/

# Equivalent long form
uv tool run ruff check .

# Install tool globally (persistent)
uv tool install ruff
uv tool install black

# List installed tools
uv tool list

# Upgrade tools
uv tool upgrade ruff
uv tool upgrade --all

# Uninstall
uv tool uninstall ruff
```

## Quick Reference

| Feature | Scripts | Tools |
|---------|---------|-------|
| Env lifetime | Per-run (ephemeral) | Persistent (global) |
| Deps declared in | Script file (PEP 723) | Package metadata |
| Run command | `uv run script.py` | `uvx <tool>` or `uv tool run` |
| Install command | N/A | `uv tool install <tool>` |
| Use case | One-off scripts, automation | CLI tools (ruff, black, mypy) |

## Common Mistakes

### Wrong

```bash
# Don't install CLI tools as project dependencies
uv add ruff  # unless you need it as a library
```

### Correct

```bash
# Use tool interface for CLI tools
uvx ruff check .
# Or install globally
uv tool install ruff
# Or as dev dependency if needed in project
uv add --dev ruff
```

## Related

- [projects](projects.md)
- [dependencies](dependencies.md)
