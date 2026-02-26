# Migration from pip/poetry/pipenv

> **Purpose**: Step-by-step migration guides from existing Python tooling to uv
> **MCP Validated**: 2026-02-19

## When to Use

- Migrating existing projects from pip + requirements.txt
- Replacing poetry with uv for faster dependency resolution
- Replacing pipenv with uv for modern lockfile support
- Consolidating multiple tools into one

## From pip + requirements.txt

```bash
# Option 1: Quick migration (pip-compatible interface)
uv pip compile requirements.in -o requirements.txt
uv pip sync requirements.txt

# Option 2: Full migration to uv project (recommended)
cd my-project
uv init --bare                     # creates pyproject.toml
uv add $(cat requirements.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ')
rm requirements.txt requirements.in  # no longer needed

# For dev requirements
uv add --dev $(cat requirements-dev.txt | grep -v '^#' | grep -v '^$' | tr '\n' ' ')
```

## From poetry

```bash
# uv reads poetry's pyproject.toml format
cd poetry-project

# Generate uv lockfile from existing pyproject.toml
uv lock

# Sync environment
uv sync

# Remove poetry artifacts (after verifying uv.lock works)
rm poetry.lock
# Remove [tool.poetry] sections from pyproject.toml if converting fully
```

Key differences from poetry:
- `uv add` replaces `poetry add`
- `uv run` replaces `poetry run`
- `uv sync` replaces `poetry install`
- `uv.lock` replaces `poetry.lock` (cross-platform)
- No need for `poetry shell` — use `uv run` directly

## From pipenv

```bash
cd pipenv-project

# Initialize uv project
uv init --bare

# Convert Pipfile dependencies
# Manually add deps from Pipfile to pyproject.toml or:
uv add requests flask gunicorn     # add your deps

# Remove pipenv artifacts
rm Pipfile Pipfile.lock
```

## Configuration

| pip/poetry/pipenv | uv equivalent |
|-------------------|---------------|
| `requirements.txt` | `pyproject.toml` + `uv.lock` |
| `setup.py` / `setup.cfg` | `pyproject.toml` |
| `poetry.lock` | `uv.lock` |
| `Pipfile.lock` | `uv.lock` |
| `.python-version` (pyenv) | `.python-version` (compatible) |
| `pip install -e .` | `uv sync` (auto editable) |
| `pip install -r req.txt` | `uv pip sync req.txt` or `uv sync` |
| `poetry add pkg` | `uv add pkg` |
| `poetry run cmd` | `uv run cmd` |

## Example Usage

```bash
# Full migration workflow
git checkout -b migrate-to-uv

# Init and migrate
uv init --bare
uv add requests fastapi sqlalchemy
uv add --dev pytest ruff mypy

# Verify everything works
uv run pytest
uv run python -c "import fastapi; print('OK')"

# Clean up old files
rm -f requirements*.txt Pipfile* poetry.lock setup.py setup.cfg
git add pyproject.toml uv.lock .python-version
git commit -m "Migrate from pip/poetry to uv"
```

## See Also

- [../concepts/projects](../concepts/projects.md)
- [../concepts/dependencies](../concepts/dependencies.md)
