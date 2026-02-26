# Architecture

> **Purpose**: How flake8 wraps pyflakes, pycodestyle, and mccabe into a unified linter
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Flake8 is a wrapper that orchestrates three independent Python analysis tools: pycodestyle (PEP 8 style checking), pyflakes (logical error detection), and mccabe (cyclomatic complexity measurement). It provides a single CLI, unified configuration, and a plugin system that allows third-party checkers to integrate seamlessly.

## The Pattern

```text
flake8 (orchestrator)
  |
  +-- pycodestyle (E/W codes)
  |     Checks: whitespace, indentation, line length, imports, blank lines
  |     Focus: PEP 8 style compliance
  |
  +-- pyflakes (F codes)
  |     Checks: unused imports, undefined names, redefined names, shadowing
  |     Focus: Logical errors without executing code
  |
  +-- mccabe (C codes)
  |     Checks: cyclomatic complexity per function
  |     Focus: Code complexity measurement
  |
  +-- plugins (B, S, D, I, ... codes)
        Checks: varies by plugin
        Focus: Extended analysis via setuptools entry points
```

## How It Works

### 1. File Discovery

Flake8 walks the directory tree, applying `exclude` and `filename` patterns to select Python files. It respects `.gitignore`-style patterns.

### 2. AST Parsing

Each file is parsed into an Abstract Syntax Tree (AST). If parsing fails, flake8 reports `E999` (syntax error) and skips further checks on that file.

### 3. Checker Execution

Flake8 runs two types of checkers:

```text
AST Checkers (tree-based):
  - pyflakes: walks the AST for import/name analysis
  - mccabe: walks the AST to count branches
  - plugins: any checker registered as ast_type

Physical Line Checkers (line-based):
  - pycodestyle: checks raw text line by line
  - plugins: any checker registered as physical_line

Logical Line Checkers:
  - pycodestyle: checks logically joined lines
  - plugins: any checker registered as logical_line
```

### 4. Result Aggregation

All checkers report violations in a standard format:
`filename:line:column: CODE message`

Results are sorted by file, then line number.

## Plugin System

Plugins register via setuptools entry points in their `setup.cfg` or `pyproject.toml`:

```ini
# Plugin's setup.cfg
[options.entry_points]
flake8.extension =
    B = flake8_bugbear:BugBearChecker
```

Flake8 discovers all installed plugins automatically at startup. No configuration is needed to enable them -- just `pip install` the plugin.

### Plugin Types

| Type | Interface | Receives |
|------|-----------|----------|
| AST checker | `class` with `run()` method | Parsed AST tree |
| Physical line | `function(physical_line)` | Raw text line |
| Logical line | `function(logical_line)` | Joined continuation lines |

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `flake8 --version` | Lists all active checkers/plugins | Verify what's loaded |
| `pip install flake8` | Installs pycodestyle + pyflakes + mccabe | Core trio |
| `E999` reported | File has syntax errors | Other checks skipped |

## Version History

| Version | Key Change |
|---------|------------|
| 1.x | Original wrapper (pep8 + pyflakes) |
| 2.x | Plugin system, mccabe added |
| 3.x | Dropped Python 2, improved config |
| 4.x | Dropped `--diff`, removed `--install-hook` |
| 5.x | Plugin API changes, setuptools modernization |
| 6.x | Python 3.8.1+ required |
| 7.x | Current (7.3.0); Python 3.14 support, pycodestyle 2.13.0, pyflakes 3.3.0 |

## Common Mistakes

### Wrong

```bash
# Running pycodestyle and flake8 separately (redundant)
pycodestyle src/
flake8 src/
```

### Correct

```bash
# flake8 already includes pycodestyle
flake8 src/
```

## Related

- [error-codes.md](error-codes.md) - Error codes from each component
- [plugins.md](plugins.md) - Third-party plugin ecosystem
- [configuration.md](configuration.md) - Unified configuration for all checkers
