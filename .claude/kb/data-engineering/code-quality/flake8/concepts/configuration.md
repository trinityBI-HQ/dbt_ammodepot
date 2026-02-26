# Configuration

> **Purpose**: Config file formats, options, and precedence for flake8
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Flake8 reads configuration from INI-format files under a `[flake8]` section. Supported files are `.flake8`, `setup.cfg`, and `tox.ini`. For `pyproject.toml` support, the `flake8-pyproject` plugin is required. Command-line arguments always override file-based config.

## The Pattern

```ini
# .flake8 (recommended - dedicated config file)
[flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = E203, W503
per-file-ignores =
    __init__.py: F401
    tests/*: S101
exclude =
    .git,
    __pycache__,
    .venv,
    build,
    dist
```

## Config File Discovery

Flake8 searches for config in this order (first found wins):

1. `.flake8` in the current directory (or parent directories)
2. `setup.cfg` with a `[flake8]` section
3. `tox.ini` with a `[flake8]` section

It does NOT natively read `pyproject.toml`. Use `flake8-pyproject` for that.

## Core Options

| Option | Default | Description |
|--------|---------|-------------|
| `max-line-length` | 79 | Maximum allowed line length |
| `max-doc-length` | None | Maximum docstring line length |
| `max-complexity` | -1 (off) | McCabe complexity threshold |
| `select` | E,F,W | Error codes to check |
| `extend-select` | (none) | Add codes without replacing defaults |
| `ignore` | (none) | Error codes to skip |
| `extend-ignore` | (none) | Add ignores without replacing defaults |
| `per-file-ignores` | (none) | File-glob-specific ignores |
| `exclude` | `.svn,CVS,.bzr,.hg,.git,__pycache__,.tox,.eggs,*.egg` | Paths to skip |
| `extend-exclude` | (none) | Add excludes without replacing defaults |
| `filename` | `*.py` | Glob pattern for files to check |
| `format` | default | Output format (default, pylint, or custom) |
| `show-source` | false | Show source code with errors |
| `statistics` | false | Show error count summary |
| `count` | false | Print total errors |

## Select vs Ignore Precedence

```text
Evaluation order:
1. Start with ALL available codes
2. Apply --select (narrows to only these prefixes)
3. Apply --extend-select (adds back specific codes)
4. Apply --ignore (removes specific codes)
5. Apply --extend-ignore (removes additional codes)
6. Apply --per-file-ignores (per-file overrides)
```

**Key rule**: Prefer `extend-ignore` over `ignore` to avoid accidentally dropping default checks.

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `extend-ignore = E203` | Adds E203 to ignore list | Preserves defaults |
| `ignore = E501` | Replaces entire ignore list | Drops other ignores |
| `select = E,W` | Checks only E and W codes | Disables F checks |
| `extend-select = C9` | Adds mccabe checks | Preserves defaults |

## Common Mistakes

### Wrong

```ini
# Using ignore instead of extend-ignore
# This replaces ALL ignores, not extends them
[flake8]
ignore = E501
```

### Correct

```ini
# Using extend-ignore preserves the default ignore list
[flake8]
extend-ignore = E501
```

### Wrong

```ini
# Inline comments after values (NOT supported in .flake8)
[flake8]
max-line-length = 120  # my preference
```

### Correct

```ini
# Comments on their own line
[flake8]
# My preference for line length
max-line-length = 120
```

## pyproject.toml Support

```bash
pip install flake8-pyproject
```

```toml
# pyproject.toml
[tool.flake8]
max-line-length = 120
extend-ignore = ["E203", "W503"]
per-file-ignores = ["__init__.py: F401", "tests/*: S101"]
exclude = [".git", "__pycache__", ".venv"]
```

## Related

- [error-codes.md](error-codes.md) - What each code means
- [inline-control.md](inline-control.md) - Per-line suppression with noqa
- [../patterns/project-configuration.md](../patterns/project-configuration.md) - Full project setup
