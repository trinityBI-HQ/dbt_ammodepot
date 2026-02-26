# Flake8 Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Error Code Families

| Prefix | Source | Category |
|--------|--------|----------|
| E1xx | pycodestyle | Indentation |
| E2xx | pycodestyle | Whitespace |
| E3xx | pycodestyle | Blank lines |
| E4xx | pycodestyle | Imports |
| E5xx | pycodestyle | Line length |
| E7xx | pycodestyle | Statements |
| E9xx | pycodestyle | Runtime/syntax errors |
| W1xx | pycodestyle | Indentation warnings |
| W2xx | pycodestyle | Whitespace warnings |
| W3xx | pycodestyle | Blank line warnings |
| W5xx | pycodestyle | Line break warnings |
| W6xx | pycodestyle | Deprecation warnings |
| F4xx | pyflakes | Import errors |
| F8xx | pyflakes | Name/scope errors |
| F9xx | pyflakes | Syntax/annotation errors |
| C901 | mccabe | Cyclomatic complexity |
| B0xx | flake8-bugbear | Likely bugs |
| B9xx | flake8-bugbear | Opinionated checks |
| S1xx-S7xx | flake8-bandit | Security issues |

## Most Common Errors

| Code | Description | Fix |
|------|-------------|-----|
| E501 | Line too long | Wrap or set `max-line-length = 120` |
| E302 | Expected 2 blank lines | Add blank lines between top-level defs |
| E303 | Too many blank lines | Remove extra blank lines |
| W291 | Trailing whitespace | Strip trailing spaces |
| F401 | Imported but unused | Remove unused import |
| F841 | Local variable unused | Remove or use the variable |
| E711 | Comparison to None | Use `is None` instead of `== None` |
| E712 | Comparison to bool | Use `if x:` instead of `if x == True:` |

## Config File Priority

| File | Scope | Notes |
|------|-------|-------|
| `.flake8` | Project-specific | Recommended; flake8-only |
| `setup.cfg` | Project-wide | Shared with setuptools |
| `tox.ini` | Project-wide | Shared with tox |
| `pyproject.toml` | Project-wide | Requires `flake8-pyproject` plugin |

## CLI Cheat Sheet

| Command | Effect |
|---------|--------|
| `flake8 .` | Lint current directory |
| `flake8 --select E,W` | Only show E and W codes |
| `flake8 --ignore E501` | Skip line-length check |
| `flake8 --max-line-length 120` | Set line length to 120 |
| `flake8 --max-complexity 10` | Enable McCabe (C901) |
| `flake8 --statistics` | Show error counts summary |
| `flake8 --count` | Print total error count |
| `flake8 --show-source` | Show source code for errors |
| `flake8 --format=pylint` | Use pylint output format |

## Inline Suppression

| Syntax | Effect |
|--------|--------|
| `# noqa` | Suppress all errors on line |
| `# noqa: E501` | Suppress only E501 on line |
| `# noqa: E501,F401` | Suppress multiple codes |
| `# type: ignore` | Suppress mypy (not flake8) |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use blanket `# noqa` | Specify codes: `# noqa: E501` |
| Put `# flake8: noqa: F401` at file top | Use `per-file-ignores` in config |
| Configure in `pyproject.toml` without plugin | Install `flake8-pyproject` first |
| Ignore all E5xx globally | Set `max-line-length` to your preference |

## Related Documentation

| Topic | Path |
|-------|------|
| Error Codes | `concepts/error-codes.md` |
| Configuration | `concepts/configuration.md` |
| Full Index | `index.md` |
