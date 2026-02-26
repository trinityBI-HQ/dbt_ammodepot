# Installation

> **Purpose**: Installing uv and getting started
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

uv is an extremely fast Python package and project manager written in Rust by Astral. It replaces pip, pip-tools, pipx, poetry, pyenv, virtualenv, and twine with a single unified tool that is 10-100x faster than pip.

## The Pattern

```bash
# Standalone installer (recommended) - macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# Via pip (if Python already installed)
pip install uv

# Via pipx
pipx install uv

# Via Homebrew
brew install uv

# Self-update (standalone installer only)
uv self update
```

## Quick Reference

| Method | Requires Python | Auto-updates | Best For |
|--------|----------------|--------------|----------|
| `curl` installer | No | `uv self update` | Fresh systems, CI |
| `pip install uv` | Yes | `pip install --upgrade uv` | Existing Python setups |
| `pipx install uv` | Yes | `pipx upgrade uv` | Isolated tool install |
| `brew install uv` | No | `brew upgrade uv` | macOS users |

## Key Features

- **Single binary**: No Python runtime required for installation
- **Cross-platform**: macOS, Linux, Windows
- **Global cache**: `~/.cache/uv/` deduplicates across projects
- **pip-compatible**: Drop-in `uv pip` interface for migration
- **PATH integration (v0.8+)**: `uv python install` places versioned executables in `~/.local/bin` by default

## Configuration

```bash
# Environment variables
export UV_CACHE_DIR=/custom/cache/path
export UV_PYTHON_PREFERENCE=managed  # prefer uv-managed Python

# Per-project config in pyproject.toml
# [tool.uv]
# python-preference = "managed"

# Or standalone uv.toml
# python-preference = "managed"
```

## Common Mistakes

### Wrong

```bash
# Don't use sudo with uv
sudo uv pip install package
```

### Correct

```bash
# uv manages its own virtual environments
uv add package
```

## Related

- [projects](projects.md)
- [python-management](python-management.md)
