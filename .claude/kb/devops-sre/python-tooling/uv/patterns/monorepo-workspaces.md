# Monorepo Workspaces

> **Purpose**: Patterns for managing multi-package Python monorepos with uv workspaces
> **MCP Validated**: 2026-02-19

## When to Use

- Multiple related services sharing common libraries
- Platform with API, worker, and shared packages
- Teams wanting consistent dependency versions across packages
- Projects where inter-package dependencies are common

## Implementation

```
platform/
├── pyproject.toml              # Workspace root
├── uv.lock                     # Single lockfile for all packages
├── .python-version
├── libs/
│   ├── core/                   # Shared models, utils
│   │   ├── pyproject.toml
│   │   └── src/core/
│   └── db/                     # Database layer
│       ├── pyproject.toml
│       └── src/db/
├── services/
│   ├── api/                    # FastAPI service
│   │   ├── pyproject.toml
│   │   └── src/api/
│   └── worker/                 # Background processor
│       ├── pyproject.toml
│       └── src/worker/
└── tools/
    └── cli/                    # Developer CLI
        ├── pyproject.toml
        └── src/cli/
```

### Root pyproject.toml

```toml
[project]
name = "platform"
version = "0.1.0"
requires-python = ">=3.12"

[tool.uv.workspace]
members = [
    "libs/*",
    "services/*",
    "tools/*",
]
```

### Library Package (libs/core)

```toml
[project]
name = "core"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["pydantic>=2.0"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### Service Package (services/api)

```toml
[project]
name = "api"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.100",
    "core",                     # workspace dependency
    "db",                       # workspace dependency
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.uv.sources]
core = { workspace = true }
db = { workspace = true }
```

## Common Operations

```bash
# Install everything
uv sync

# Run specific service
uv run --package api uvicorn api:app
uv run --package worker python -m worker

# Add dependency to specific package
uv add --package api httpx
uv add --package core --dev pytest

# Run tests for specific package
uv run --package core pytest
uv run --package api pytest

# Build specific package
uv build --package core
```

## Docker with Workspaces

```dockerfile
FROM python:3.12-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

WORKDIR /app
ENV UV_LINK_MODE=copy

# Copy workspace root + lockfile
COPY pyproject.toml uv.lock ./

# Copy all member pyproject.toml files for dep resolution
COPY libs/core/pyproject.toml libs/core/pyproject.toml
COPY libs/db/pyproject.toml libs/db/pyproject.toml
COPY services/api/pyproject.toml services/api/pyproject.toml

# Install deps (cached layer)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --package api --no-install-workspace --no-dev

# Copy all source
COPY . .

# Install workspace packages
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --package api --no-dev

FROM python:3.12-slim
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
COPY --from=builder /app .
CMD ["uvicorn", "api:app", "--host", "0.0.0.0"]
```

## See Also

- [../concepts/workspaces](../concepts/workspaces.md)
- [docker-integration](docker-integration.md)
