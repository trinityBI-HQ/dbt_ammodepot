# uv Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Core Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `uv init` | Create new project | `uv init my-app` |
| `uv add` | Add dependency | `uv add requests` |
| `uv remove` | Remove dependency | `uv remove flask` |
| `uv sync` | Sync environment to lockfile | `uv sync` |
| `uv lock` | Generate/update lockfile | `uv lock` |
| `uv run` | Run command in project env | `uv run python main.py` |
| `uv build` | Build distribution archives | `uv build` |
| `uv publish` | Publish to PyPI | `uv publish` |
| `uv tree` | Show dependency tree | `uv tree` |

## Python Management

| Command | Purpose | Example |
|---------|---------|---------|
| `uv python install` | Install Python version | `uv python install 3.12` |
| `uv python upgrade` | Upgrade to latest patch/minor | `uv python upgrade 3.12` |
| `uv python list` | List available versions | `uv python list` |
| `uv python find` | Find installed version | `uv python find 3.11` |
| `uv python pin` | Pin project Python version | `uv python pin 3.12` |

## Scripts & Tools

| Command | Purpose | Example |
|---------|---------|---------|
| `uv run script.py` | Run script with deps | `uv run example.py` |
| `uv add --script` | Add dep to script | `uv add --script app.py requests` |
| `uv run --with <pkg>` | Run with ephemeral dep | `uv run --with rich script.py` |
| `uvx` / `uv tool run` | Run tool in temp env | `uvx ruff check .` |
| `uv tool install` | Install tool globally | `uv tool install black` |

## Project Types

| Type | Flag | Use Case |
|------|------|----------|
| Application | `uv init` (default) | Web servers, CLIs, scripts |
| Packaged app | `uv init --package` | CLI tools for PyPI, projects with tests dir |
| Library | `uv init --lib` | Reusable packages for other projects |
| Minimal | `uv init --bare` | Just pyproject.toml, no boilerplate |

## Dependency Groups

| Syntax | Purpose |
|--------|---------|
| `uv add requests` | Production dependency |
| `uv add --dev pytest` | Development dependency |
| `uv add --group lint ruff` | Named dependency group |
| `uv sync --no-dev` | Install without dev deps |
| `uv sync --group lint` | Include specific group |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| New Python project | `uv init` + `uv add` |
| Existing pip project | `uv pip compile` or migrate to `uv init` |
| Run one-off tool | `uvx <tool>` |
| Script with inline deps | `uv run script.py` with PEP 723 metadata |
| Monorepo with shared deps | uv workspaces |
| Docker builds | Multi-stage with `uv sync --locked` |

## Workspace Commands (v0.10+)

| Command | Purpose | Example |
|---------|---------|---------|
| `uv workspace dir` | Show workspace root directory | `uv workspace dir` |
| `uv workspace list` | List all workspace members | `uv workspace list` |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| `pip install` in uv projects | `uv add <package>` |
| Edit uv.lock manually | `uv lock` to regenerate |
| Commit .venv directory | Add `.venv/` to `.gitignore` |
| Use `uv sync` without `--locked` in CI | `uv sync --locked --no-dev` for CI |
| Skip `uv cache prune --ci` in pipelines | Run it to minimize cache size |
| Set multiple indexes as `default = true` | Only one index can be default (v0.10) |
| Omit `name` on explicit indexes | All `[[tool.uv.index]]` entries need a name (v0.10) |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/installation.md` |
| Full Index | `index.md` |
