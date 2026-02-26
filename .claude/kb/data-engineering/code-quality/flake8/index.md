# Flake8 Knowledge Base

> **Purpose**: Python linting tool wrapping PyFlakes, pycodestyle, and McCabe for style enforcement and bug detection (v7.3.0)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/architecture.md](concepts/architecture.md) | How flake8 wraps pyflakes + pycodestyle + mccabe |
| [concepts/error-codes.md](concepts/error-codes.md) | E/W/F/C code families and what they mean |
| [concepts/configuration.md](concepts/configuration.md) | Config files: .flake8, setup.cfg, pyproject.toml |
| [concepts/plugins.md](concepts/plugins.md) | Plugin ecosystem (bugbear, bandit, import-order, etc.) |
| [concepts/inline-control.md](concepts/inline-control.md) | noqa comments, per-file-ignores, suppression |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/project-configuration.md](patterns/project-configuration.md) | Standard project setup for data engineering |
| [patterns/ci-cd-integration.md](patterns/ci-cd-integration.md) | Pre-commit, GitHub Actions, Azure DevOps |
| [patterns/plugin-stack.md](patterns/plugin-stack.md) | Recommended plugin combinations |
| [patterns/migration-to-ruff.md](patterns/migration-to-ruff.md) | How and when to migrate from flake8 to ruff |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Error Codes** | Prefixed codes (E/W/F/C) from pycodestyle, pyflakes, and mccabe |
| **Configuration** | INI-based config in .flake8, setup.cfg, or tox.ini |
| **Plugins** | Extensible checker system via setuptools entry points |
| **noqa** | Inline comment to suppress specific violations per line |
| **per-file-ignores** | Config-level suppression scoped to file glob patterns |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/architecture.md, concepts/error-codes.md |
| **Intermediate** | concepts/configuration.md, patterns/project-configuration.md |
| **Advanced** | concepts/plugins.md, patterns/plugin-stack.md, patterns/migration-to-ruff.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| Code Review | error-codes.md, inline-control.md | Understanding and fixing lint violations |
| Project Setup | project-configuration.md, plugin-stack.md | Bootstrapping flake8 in a new project |
| CI/CD | ci-cd-integration.md | Adding flake8 to pipelines |
| Migration | migration-to-ruff.md | Evaluating ruff as a replacement |

---

## Version History

| Version | Date | Key Change |
|---------|------|------------|
| **7.3.0** | Jun 2025 | Python 3.14 support, updated pycodestyle 2.13.0 and pyflakes 3.3.0 |
| 7.1.x | 2024 | Python 3.8.1+ required, improved caching |
| 6.x | 2023 | Python 3.8.1+ required |

**Note:** Ruff ecosystem pressure continues growing, but Flake8 remains stable and widely used, especially for teams with custom plugin dependencies.

## Installation

```bash
# With pip
pip install flake8

# With uv (recommended for this project)
uv pip install flake8

# Verify installation
flake8 --version
# 7.3.0 (mccabe: 0.7.0, pycodestyle: 2.13.0, pyflakes: 3.3.0)
```

## Basic Usage

```bash
# Lint a single file
flake8 path/to/file.py

# Lint a directory
flake8 src/

# Show specific error codes only
flake8 --select E501,W291 src/

# Ignore specific codes
flake8 --ignore E501 src/

# Set max line length
flake8 --max-line-length 120 src/
```
