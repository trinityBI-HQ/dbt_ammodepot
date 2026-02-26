# Plugin Stack

> **Purpose**: Recommended flake8 plugin combinations for data engineering projects
> **MCP Validated**: 2026-02-19

## When to Use

- Starting a new data engineering project and choosing plugins
- Standardizing linting plugins across a team
- Balancing strictness with developer productivity
- Need security checking in data pipeline code

## Implementation

### Tier 1: Essential (Always Install)

```bash
pip install \
    flake8 \
    flake8-bugbear \
    flake8-bandit
```

| Plugin | Codes | Why Essential |
|--------|-------|---------------|
| `flake8-bugbear` | B0xx, B9xx | Catches mutable defaults, bare excepts, common Python bugs |
| `flake8-bandit` | S1xx-S7xx | Detects hardcoded passwords, SQL injection, assert in prod |

```ini
# .flake8 - Tier 1 config
[flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = E203, W503, E501
extend-select = B,B950,S
per-file-ignores =
    __init__.py: F401
    tests/*: S101
```

### Tier 2: Recommended (Team Projects)

```bash
pip install \
    flake8 \
    flake8-bugbear \
    flake8-bandit \
    flake8-import-order \
    flake8-comprehensions \
    flake8-simplify
```

| Plugin | Codes | Why Recommended |
|--------|-------|-----------------|
| `flake8-import-order` | I | Consistent import ordering across the team |
| `flake8-comprehensions` | C4xx | Simplify list/dict/set comprehensions |
| `flake8-simplify` | SIM | Suggests code simplifications |

```ini
# .flake8 - Tier 2 config
[flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = E203, W503, E501
extend-select = B,B950,S,C4,SIM
import-order-style = google
per-file-ignores =
    __init__.py: F401
    tests/*: S101
```

### Tier 3: Comprehensive (Strict Codebase)

```bash
pip install \
    flake8 \
    flake8-bugbear \
    flake8-bandit \
    flake8-import-order \
    flake8-comprehensions \
    flake8-simplify \
    flake8-docstrings \
    flake8-annotations \
    flake8-pytest-style \
    flake8-return
```

| Plugin | Codes | Why It Helps |
|--------|-------|--------------|
| `flake8-docstrings` | D1xx-D4xx | Enforce docstrings on all public APIs |
| `flake8-annotations` | ANN | Enforce type hints on functions |
| `flake8-pytest-style` | PT | Pytest best practices |
| `flake8-return` | R5xx | Consistent return statements |

```ini
# .flake8 - Tier 3 config
[flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = E203, W503, E501, D100, D104
extend-select = B,B950,S,C4,SIM,ANN,PT,R
import-order-style = google
docstring-convention = google
per-file-ignores =
    __init__.py: F401,D104
    tests/*: S101,D100,D103,ANN
    migrations/*: D,ANN
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `import-order-style` | cryptography | Import grouping style (google, smarkets, appnexus) |
| `docstring-convention` | pep257 | Docstring style (google, numpy, pep257) |
| `min-python-version` | 3.8 | Target Python version for annotations |

## Data Engineering Plugin Selection Guide

| Project Type | Tier | Rationale |
|--------------|------|-----------|
| Solo ETL scripts | Tier 1 | Catch bugs, minimal overhead |
| Team dbt+Dagster monorepo | Tier 2 | Consistency without friction |
| Production data platform | Tier 3 | Full documentation and type safety |
| Legacy migration | Tier 1 | Low friction while improving |

### Dagster-Specific Considerations

```ini
per-file-ignores =
    # Dagster definitions use star imports
    **/definitions.py: F401,F403
    # Asset functions often have complex signatures
    **/assets.py: ANN,D103
    # Sensor functions may have high complexity
    **/sensors.py: C901
```

### dbt Python Models

```ini
per-file-ignores =
    # dbt Python models have a required function signature
    models/**/*.py: ANN,D103
```

## Plugin Version Pinning

Always pin plugin versions in `requirements-lint.txt`:

```text
# requirements-lint.txt
flake8==7.3.0
flake8-bugbear==24.8.19
flake8-bandit==4.1.1
flake8-import-order==0.18.2
flake8-comprehensions==3.15.0
flake8-simplify==0.21.0
```

```bash
pip install -r requirements-lint.txt
```

## Example Usage

```bash
# Check what plugins are active
flake8 --version

# Run with only bugbear codes
flake8 --select B src/

# Test a new plugin before adding to config
pip install flake8-return
flake8 --select R src/
```

## See Also

- [../concepts/plugins.md](../concepts/plugins.md) - Plugin ecosystem overview
- [project-configuration.md](project-configuration.md) - Base project config
- [ci-cd-integration.md](ci-cd-integration.md) - Running plugins in CI
- [migration-to-ruff.md](migration-to-ruff.md) - Ruff reimplements most plugins natively
