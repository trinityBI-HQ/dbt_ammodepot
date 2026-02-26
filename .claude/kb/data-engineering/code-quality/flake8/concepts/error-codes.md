# Error Codes

> **Purpose**: Comprehensive reference for flake8 error/warning code families
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Flake8 error codes are prefixed letters followed by three digits. Each prefix maps to a specific checker tool. The core prefixes are E and W (pycodestyle), F (pyflakes), and C (mccabe). Plugins add their own prefixes (B for bugbear, S for bandit, etc.).

## The Pattern

```text
E501 line too long (82 > 79 characters)
^---
|
E = pycodestyle error
5 = category (line length)
01 = specific violation
```

## pycodestyle Codes (E/W)

| Range | Category | Examples |
|-------|----------|----------|
| E1xx | Indentation | E101 mixed tabs/spaces, E111 expected indentation, E117 over-indented |
| E2xx | Whitespace | E201 whitespace after `(`, E225 missing space around operator, E231 missing space after `,` |
| E3xx | Blank lines | E301 expected 1 blank line, E302 expected 2 blank lines, E303 too many blank lines |
| E4xx | Imports | E401 multiple imports on one line, E402 module-level import not at top |
| E5xx | Line length | E501 line too long (default 79 chars) |
| E7xx | Statements | E711 comparison to None, E712 comparison to bool, E721 type comparison, E741 ambiguous variable name |
| E9xx | Runtime | E999 syntax error (cannot compile to AST) |
| W1xx | Indentation | W191 indentation contains tabs |
| W2xx | Whitespace | W291 trailing whitespace, W292 no newline at end of file, W293 whitespace before comment |
| W3xx | Blank lines | W391 blank line at end of file |
| W5xx | Line breaks | W503 line break before binary operator, W504 line break after binary operator |
| W6xx | Deprecated | W605 invalid escape sequence |

## pyflakes Codes (F)

| Range | Category | Examples |
|-------|----------|----------|
| F4xx | Imports | F401 imported but unused, F403 `from x import *`, F405 undefined name from star import |
| F5xx | String formatting | F501 invalid `%` format, F522 `.format()` unused args |
| F6xx | Expressions | F601 `in` with list literal (use set), F621 too many expressions in starred assignment |
| F7xx | Control flow | F701 syntax error in type comment, F811 redefinition of unused name |
| F8xx | Names | F811 redefined unused name, F821 undefined name, F841 local variable assigned but never used |
| F9xx | Annotations | F901 `raise NotImplemented` should be `raise NotImplementedError` |

## mccabe Code (C)

| Code | Description | Default |
|------|-------------|---------|
| C901 | Function complexity exceeds threshold | Disabled unless `--max-complexity` is set |

McCabe measures cyclomatic complexity. A function with no branches has complexity 1. Each `if`, `for`, `while`, `except`, `and`, `or` adds 1. Recommended threshold: 10.

## Default Ignored Codes

These codes lack unanimous PEP 8 consensus and are off by default:

```text
E121, E123, E126, E133, E226, E241, E242, E704, W503, W504, W505
```

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `flake8 --select E501` | Only line-length errors | Narrow check |
| `flake8 --select E,W,F` | All pycodestyle + pyflakes | Standard run |
| `flake8 --extend-ignore E501` | Skip line length | Additive ignore |
| `flake8 --max-complexity 10` | Enable C901 checks | Must be explicit |

## Common Mistakes

### Wrong

```python
# Using == None (triggers E711)
if value == None:
    pass

# Type comparison with == (triggers E721)
if type(x) == int:
    pass
```

### Correct

```python
# Use identity comparison
if value is None:
    pass

# Use isinstance
if isinstance(x, int):
    pass
```

## Related

- [configuration.md](configuration.md) - How to configure which codes to check
- [inline-control.md](inline-control.md) - How to suppress specific codes
- [../patterns/project-configuration.md](../patterns/project-configuration.md) - Standard project setup
