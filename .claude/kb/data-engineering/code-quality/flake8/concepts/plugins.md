# Plugins

> **Purpose**: Overview of flake8's plugin ecosystem and popular extensions
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Flake8 uses setuptools entry points for plugin discovery. Any installed package that registers a `flake8.extension` entry point is automatically loaded. Plugins add new error code prefixes and checks beyond the core E/W/F/C codes. There are 200+ plugins available on PyPI.

## The Pattern

```bash
# Install plugins alongside flake8
pip install flake8 flake8-bugbear flake8-bandit flake8-import-order

# Plugins activate automatically - no config needed
flake8 --version
# 7.3.0 (flake8-bugbear: 24.8.19, flake8-bandit: 4.1.1, ...)

# Plugin codes appear in output
flake8 src/
# src/app.py:10:1: B006 Do not use mutable data structures for argument defaults
# src/app.py:15:5: S101 Use of assert detected
```

## Popular Plugins

### Bug Detection

| Plugin | Codes | Description |
|--------|-------|-------------|
| `flake8-bugbear` | B0xx, B9xx | Finds likely bugs and design problems |
| `flake8-comprehensions` | C4xx | Simplifies unnecessary list/dict/set comprehensions |
| `flake8-simplify` | SIM | Suggests code simplifications |
| `flake8-return` | R5xx | Checks return statement consistency |
| `flake8-pie` | PIE | Miscellaneous lint rules (unnecessary pass, etc.) |

### Security

| Plugin | Codes | Description |
|--------|-------|-------------|
| `flake8-bandit` | S1xx-S7xx | Security checks via bandit (assert, exec, SQL injection) |

### Style and Formatting

| Plugin | Codes | Description |
|--------|-------|-------------|
| `flake8-docstrings` | D1xx-D4xx | Docstring conventions via pydocstyle (PEP 257) |
| `flake8-import-order` | I | Import ordering (isort-style checks) |
| `flake8-quotes` | Q0xx | Enforce consistent string quoting style |
| `flake8-commas` | C8xx | Trailing comma enforcement |
| `flake8-black` | BLK | Black formatting compatibility checks |

### Type Checking

| Plugin | Codes | Description |
|--------|-------|-------------|
| `flake8-annotations` | ANN | Enforce type annotations on functions |
| `flake8-pyi` | Y0xx | Type stub (.pyi) file checks |

### Testing

| Plugin | Codes | Description |
|--------|-------|-------------|
| `flake8-pytest-style` | PT | Pytest best practices (fixtures, marks, raises) |
| `flake8-pytest` | T | Print statement detection in production code |

### Data Engineering Relevant

| Plugin | Codes | Why It Matters |
|--------|-------|----------------|
| `flake8-bugbear` | B0xx | Catches mutable defaults common in pipeline functions |
| `flake8-bandit` | S1xx | Detects hardcoded credentials in connection strings |
| `flake8-import-order` | I | Consistent imports across team codebases |
| `flake8-docstrings` | D1xx | Documents transformation logic and macros |

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `pip install flake8-bugbear` | Enables B0xx codes | Auto-detected |
| `--select B` | Only bugbear checks | Plugin codes work like built-in |
| `--extend-ignore B950` | Skip opinionated line check | B950 is 10% tolerance |

## Common Mistakes

### Wrong

```ini
# Trying to enable a plugin via config (not needed)
[flake8]
enable-extensions = bugbear
```

### Correct

```bash
# Just install it - plugins auto-register
pip install flake8-bugbear
# Then run flake8 normally
flake8 src/
```

## Related

- [error-codes.md](error-codes.md) - Core error code reference
- [../patterns/plugin-stack.md](../patterns/plugin-stack.md) - Recommended plugin combinations
- [../patterns/project-configuration.md](../patterns/project-configuration.md) - Full project setup with plugins
