# Inline Control

> **Purpose**: How to suppress specific violations using noqa comments and per-file-ignores
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Flake8 provides two mechanisms for selectively suppressing violations: inline `# noqa` comments for per-line control and `per-file-ignores` in config for file-level patterns. Proper use of these tools keeps your codebase clean while allowing justified exceptions.

## The Pattern

```python
# Suppress a specific code on one line
import os  # noqa: F401

# Suppress multiple codes
from module import *  # noqa: F401,F403

# Blanket suppress (avoid this - hides all errors)
some_long_line_that_should_be_wrapped = very_long_expression  # noqa
```

## noqa Syntax Rules

The exact syntax matters. Incorrect formatting silently degrades to blanket suppression.

| Syntax | Interpreted As | Correct? |
|--------|---------------|----------|
| `# noqa: E501` | Suppress E501 only | Yes |
| `# noqa: E501,F401` | Suppress E501 and F401 | Yes |
| `# noqa: E501, F401` | Suppress E501 and F401 | Yes |
| `# noqa` | Suppress ALL errors | Avoid |
| `# noqa E501` | Suppress ALL (no colon!) | Bug |
| `# noqa : E501` | Suppress ALL (extra space!) | Bug |
| `# NOQA: E501` | Suppress E501 (case-insensitive) | Yes |

**Critical**: Missing the colon or adding a space before it turns a targeted suppression into a blanket one.

## per-file-ignores (Config-Level)

Set in your config file to suppress codes for specific file patterns.

```ini
[flake8]
per-file-ignores =
    # Allow unused imports in __init__.py (re-exports)
    __init__.py: F401
    # Allow assert in tests (used by pytest)
    tests/*: S101
    # Allow star imports in settings
    settings.py: F403,F405
    # Allow long lines in migrations
    migrations/*: E501
```

## File-Level Suppression

There is NO file-level noqa that targets specific codes.

```python
# flake8: noqa
# This suppresses ALL errors in the entire file.
# The code part is SILENTLY IGNORED:
# flake8: noqa: F401  <-- Still suppresses ALL errors, not just F401
```

Use `per-file-ignores` in config instead of file-level `# flake8: noqa`.

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `# noqa: E501` | Suppress E501 on that line | Targeted suppression |
| `# noqa: E501,W291` | Suppress E501 and W291 | Multiple codes |
| `# noqa` | Suppress ALL on that line | Use sparingly |
| `# flake8: noqa` | Suppress ALL in file | Avoid; use per-file-ignores |
| `per-file-ignores` | Config-level, glob-scoped | Preferred for patterns |

## When to Use Each

```text
Single line exception   --> # noqa: E501
File pattern exception  --> per-file-ignores in config
Entire file exception   --> per-file-ignores with exact path
Temporary debugging     --> # noqa (remove before commit)
```

## Common Mistakes

### Wrong

```python
# Missing colon - this is a BLANKET noqa, not targeted
result = some_function(arg1, arg2, arg3, arg4)  # noqa E501
```

### Correct

```python
# With colon - properly targets only E501
result = some_function(arg1, arg2, arg3, arg4)  # noqa: E501
```

### Wrong

```python
# flake8: noqa: F401
# ^ This ignores ALL errors in the file, not just F401
import unused_module
```

### Correct

```ini
# In .flake8 config
[flake8]
per-file-ignores =
    this_file.py: F401
```

## flake8-noqa Plugin

The `flake8-noqa` plugin validates noqa comments and flags issues:

```bash
pip install flake8-noqa
```

| Code | Description |
|------|-------------|
| NQA001 | noqa comment without code is blanket suppression |
| NQA002 | noqa code is not being triggered on this line |
| NQA003 | noqa code is unrecognized |

## Related

- [error-codes.md](error-codes.md) - What each code means
- [configuration.md](configuration.md) - Config file options including per-file-ignores
- [../patterns/project-configuration.md](../patterns/project-configuration.md) - Full project setup
