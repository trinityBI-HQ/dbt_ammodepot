# Migration to Ruff

> **Purpose**: Guide for evaluating and migrating from flake8 to ruff, the Rust-powered Python linter
> **MCP Validated**: 2026-02-19

## When to Use

- flake8 is slow on large codebases (10,000+ files)
- Plugin version conflicts are causing maintenance burden
- Want to consolidate flake8 + black + isort into one tool
- Starting a new project and choosing a linter
- Need `pyproject.toml`-native configuration without extra plugins

## Implementation

### Step 1: Assess Migration Readiness

Check which flake8 plugins you use and whether ruff supports their rules:

```bash
# List your current flake8 plugins
flake8 --version

# Check ruff's rule coverage
# Ruff reimplements 800+ rules from 50+ flake8 plugins
ruff rule --all | wc -l
```

### Ruff Coverage of Common flake8 Plugins

| flake8 Plugin | Ruff Prefix | Coverage |
|---------------|-------------|----------|
| pycodestyle (E/W) | E, W | Full |
| pyflakes (F) | F | Full |
| mccabe (C) | C90 | Full |
| flake8-bugbear (B) | B | Full |
| flake8-bandit (S) | S | Partial (most rules) |
| flake8-comprehensions (C4) | C4 | Full |
| flake8-simplify (SIM) | SIM | Full |
| flake8-import-order (I) | I (isort) | Different (uses isort rules) |
| flake8-docstrings (D) | D | Full |
| flake8-annotations (ANN) | ANN | Full |
| flake8-pytest-style (PT) | PT | Full |
| flake8-return (RET) | RET | Full |
| Custom plugins | N/A | Not supported |

### Step 2: Convert Configuration

**Before (flake8):**

```ini
# .flake8
[flake8]
max-line-length = 120
max-complexity = 10
extend-ignore = E203, W503, E501
per-file-ignores =
    __init__.py: F401
    tests/*: S101
exclude =
    .git,
    __pycache__,
    .venv,
    dbt_packages,
    target
```

**After (ruff):**

```toml
# pyproject.toml
[tool.ruff]
line-length = 120
target-version = "py311"
exclude = [
    ".git",
    "__pycache__",
    ".venv",
    "dbt_packages",
    "target",
]

[tool.ruff.lint]
select = ["E", "F", "W", "B", "S", "C4", "SIM", "C90"]
ignore = ["E203", "E501"]

[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]
"tests/*" = ["S101"]

[tool.ruff.lint.mccabe]
max-complexity = 10
```

### Step 3: Run Both in Parallel

Run both tools side by side to compare output before removing flake8:

```bash
# Run both and compare
flake8 --count --statistics src/ > flake8-output.txt
ruff check --statistics src/ > ruff-output.txt

# Diff the results (codes will match, formatting may differ)
diff flake8-output.txt ruff-output.txt
```

### Step 4: Update CI/CD

**Pre-commit migration:**

```yaml
# Before: flake8
- repo: https://github.com/PyCQA/flake8
  rev: 7.3.0
  hooks:
    - id: flake8
      additional_dependencies: [flake8-bugbear, flake8-bandit]

# After: ruff
- repo: https://github.com/astral-sh/ruff-pre-commit
  rev: v0.8.0
  hooks:
    - id: ruff
      args: [--fix]
    - id: ruff-format  # replaces black too
```

## Configuration

| flake8 Option | ruff Equivalent | Notes |
|---------------|-----------------|-------|
| `max-line-length` | `line-length` | Same behavior |
| `max-complexity` | `[tool.ruff.lint.mccabe] max-complexity` | Same behavior |
| `extend-ignore` | `ignore` | Ruff uses a single list |
| `extend-select` | `select` | Ruff uses a single list |
| `per-file-ignores` | `[tool.ruff.lint.per-file-ignores]` | Dict format |
| `exclude` | `exclude` | Same glob patterns |

## Decision Matrix: Flake8 vs Ruff

| Factor | Choose flake8 | Choose ruff |
|--------|---------------|-------------|
| Custom plugins | Must use flake8 | Not supported |
| Speed matters | Slow (20s on large repos) | Fast (0.2s on large repos) |
| pyproject.toml native | Needs flake8-pyproject | Built-in |
| Auto-fix support | No (read-only) | Yes (--fix) |
| Formatting (black) | Separate tool | Built-in (ruff format) |
| Import sorting | Plugin (flake8-import-order) | Built-in (isort rules) |
| Team familiarity | Widely known | Growing rapidly |
| Stability | Mature, stable | Fast-moving, breaking changes |

## Performance Comparison

```text
Codebase: 10,000 Python files

flake8 (with 5 plugins):  ~18 seconds
ruff (equivalent rules):  ~0.15 seconds

Speed improvement: ~120x
```

## When NOT to Migrate

- You rely on custom flake8 plugins with no ruff equivalent
- Your team has extensive muscle memory with flake8 conventions
- You are mid-project and stability is more important than speed
- Your codebase is small enough that flake8 speed is not an issue

## Example Usage

```bash
# Install ruff
pip install ruff

# Check (like flake8)
ruff check .

# Check with auto-fix
ruff check --fix .

# Format (like black)
ruff format .

# Show what rules are available
ruff rule --all
```

## See Also

- [project-configuration.md](project-configuration.md) - Flake8 project setup
- [plugin-stack.md](plugin-stack.md) - Plugins that ruff replaces
- [../concepts/architecture.md](../concepts/architecture.md) - Understanding what ruff replaces
