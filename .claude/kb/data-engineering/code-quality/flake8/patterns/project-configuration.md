# Project Configuration

> **Purpose**: Standard flake8 setup pattern for data engineering projects using dbt, Dagster, and Python pipelines
> **MCP Validated**: 2026-02-19

## When to Use

- Setting up a new Python or data engineering project
- Standardizing linting across a team or monorepo
- Configuring flake8 alongside dbt, Dagster, or Airflow
- Need a battle-tested starting configuration

## Implementation

### Option A: .flake8 File (Recommended)

```ini
[flake8]
# Line length: 120 is the modern standard for data engineering
# (PEP 8's 79 is too restrictive for SQL-heavy codebases)
max-line-length = 120

# Complexity threshold (10 is a good default)
max-complexity = 10

# Extend the default ignores (don't replace them)
extend-ignore =
    # Whitespace before ':' (conflicts with Black formatting)
    E203,
    # Line break before binary operator (W503 and W504 conflict)
    W503,
    # Line too long handled by B950 (bugbear's 10% tolerance)
    E501

# Per-file ignores for common patterns
per-file-ignores =
    # Allow unused imports in __init__.py (re-exports)
    __init__.py: F401
    # Allow assert in tests (pytest relies on assert)
    tests/*: S101
    # Allow star imports in Dagster definitions
    **/definitions.py: F401,F403
    # Migrations often have long lines and unused imports
    migrations/*: E501,F401

# Directories to skip entirely
exclude =
    .git,
    __pycache__,
    .venv,
    venv,
    build,
    dist,
    *.egg-info,
    .tox,
    .mypy_cache,
    .pytest_cache,
    # dbt artifacts
    dbt_packages,
    target,
    logs

# Only check Python files
filename = *.py
```

### Option B: pyproject.toml (with flake8-pyproject)

```toml
[tool.flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = ["E203", "W503", "E501"]
per-file-ignores = [
    "__init__.py: F401",
    "tests/*: S101",
    "**/definitions.py: F401,F403",
]
exclude = [
    ".git",
    "__pycache__",
    ".venv",
    "build",
    "dist",
    "dbt_packages",
    "target",
]
```

```bash
# Must install the plugin first
pip install flake8-pyproject
```

## Configuration

| Setting | Default | Data Engineering Recommendation |
|---------|---------|--------------------------------|
| `max-line-length` | 79 | 120 (SQL strings get long) |
| `max-complexity` | off | 10 (flag complex ETL functions) |
| `extend-ignore` | none | E203, W503 (Black compat) |
| `exclude` | .git,... | Add dbt_packages, target, logs |

## Data Engineering Specifics

### dbt Projects

```ini
[flake8]
# Exclude dbt-generated artifacts
exclude =
    dbt_packages,
    target,
    logs,
    # Compiled SQL output
    **/target/**
```

### Dagster Projects

```ini
[flake8]
per-file-ignores =
    # Dagster definitions often import and re-export
    **/definitions.py: F401,F403
    # Sensor/schedule functions may have complex logic
    **/sensors.py: C901
    # Asset factories use dynamic names
    **/assets.py: F811
```

### Monorepo Pattern

For a monorepo like `dbt-orchestration-hub`, place `.flake8` at the repo root:

```text
dbt-orchestration-hub/
  .flake8                    <-- Single config for all Python
  dagster_orchestration/     <-- Linted
  clients/
    theraice/
      dbt_project/           <-- Excluded (SQL/YAML only)
  shared/
    dbt_macros/              <-- Excluded (SQL only)
```

## Example Usage

```bash
# Run with default config from .flake8
flake8 dagster_orchestration/

# Override for CI (stricter)
flake8 --max-complexity 8 dagster_orchestration/

# Show statistics for a codebase health check
flake8 --statistics --count dagster_orchestration/
```

## See Also

- [../concepts/configuration.md](../concepts/configuration.md) - Detailed config reference
- [ci-cd-integration.md](ci-cd-integration.md) - Integrating into CI/CD
- [plugin-stack.md](plugin-stack.md) - Recommended plugin combinations
