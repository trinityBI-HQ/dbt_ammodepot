# CI/CD Integration

> **Purpose**: GitHub Actions workflows and CI/CD best practices with uv
> **MCP Validated**: 2026-02-19

## When to Use

- Setting up CI pipelines for Python projects managed by uv
- Caching dependencies in GitHub Actions / GitLab CI
- Running tests, linting, type checking in CI
- Publishing packages to PyPI

## Implementation

### GitHub Actions (Recommended)

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12", "3.13"]

    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v7
        with:
          enable-cache: true

      - name: Set up Python ${{ matrix.python-version }}
        run: uv python install ${{ matrix.python-version }}

      - name: Install dependencies
        run: uv sync --locked --dev

      - name: Run linting
        run: uv run ruff check .

      - name: Run type checking
        run: uv run mypy src/

      - name: Run tests
        run: uv run pytest --cov

      - name: Minimize cache
        run: uv cache prune --ci
```

### Publish to PyPI

```yaml
  publish:
    needs: test
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    permissions:
      id-token: write  # trusted publishing

    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v7

      - name: Build package
        run: uv build

      - name: Publish to PyPI
        run: uv publish --trusted-publishing always
```

### GitLab CI

```yaml
variables:
  UV_CACHE_DIR: .uv-cache

cache:
  paths:
    - .uv-cache

stages:
  - test

test:
  image: python:3.12-slim
  before_script:
    - pip install uv
  script:
    - uv sync --locked --dev
    - uv run pytest
  after_script:
    - uv cache prune --ci
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `enable-cache` | `false` | Enable built-in cache in setup-uv action |
| `cache-dependency-glob` | `**/uv.lock` | Files to hash for cache key |
| `UV_CACHE_DIR` | system default | Override cache directory |
| `--locked` | off | Fail if lockfile out of date (use in CI) |
| `--frozen` | off | Don't update lockfile at all |

## Caching Strategy

```yaml
# Option 1: setup-uv built-in cache (simplest)
- uses: astral-sh/setup-uv@v7
  with:
    enable-cache: true

# Option 2: Manual cache with actions/cache (more control)
- uses: actions/cache@v4
  with:
    path: /tmp/.uv-cache
    key: uv-${{ runner.os }}-${{ hashFiles('uv.lock') }}
    restore-keys: |
      uv-${{ runner.os }}-${{ hashFiles('uv.lock') }}
      uv-${{ runner.os }}
```

Always run `uv cache prune --ci` at the end to minimize cache size by removing pre-built wheels (keeping only source-built wheels).

## Lockfile Validation

```yaml
# Ensure lockfile is up to date (fails if pyproject.toml changed without uv lock)
- name: Validate lockfile
  run: uv lock --check
```

## Example Usage

```bash
# Local CI simulation
uv sync --locked --dev
uv run ruff check .
uv run mypy src/
uv run pytest --cov
```

## See Also

- [docker-integration](docker-integration.md)
- [../concepts/dependencies](../concepts/dependencies.md)
