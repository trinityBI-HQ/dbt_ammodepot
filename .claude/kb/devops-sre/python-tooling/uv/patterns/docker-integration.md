# Docker Integration

> **Purpose**: Optimized Docker builds with uv for fast, reproducible container images
> **MCP Validated**: 2026-02-19

## When to Use

- Building Python application containers
- Optimizing Docker layer caching for faster builds
- Multi-stage builds for minimal production images
- CI/CD pipelines that build Docker images

## Implementation

```dockerfile
# ---- Optimized multi-stage Dockerfile ----

# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /app

# Copy dependency files first (layer caching)
COPY pyproject.toml uv.lock ./

# Install dependencies only (no project code yet)
ENV UV_LINK_MODE=copy
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-dev

# Copy project source
COPY . .

# Install the project itself
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# Stage 2: Runtime (minimal image)
FROM python:3.12-slim AS runtime

WORKDIR /app

# Copy installed environment from builder
COPY --from=builder /app/.venv /app/.venv

# Put venv on PATH
ENV PATH="/app/.venv/bin:$PATH"

# Copy application code
COPY --from=builder /app .

CMD ["python", "-m", "my_app"]
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `UV_LINK_MODE` | `symlink` | Set to `copy` inside Docker (no symlink to cache) |
| `UV_CACHE_DIR` | `/root/.cache/uv` | Cache mount target |
| `UV_COMPILE_BYTECODE` | `0` | Set to `1` for faster startup |
| `UV_PYTHON_DOWNLOADS` | `automatic` | Set to `never` to use base image Python |

## Layer Caching Strategy

```dockerfile
# Order matters for cache efficiency:
# 1. Install uv (rarely changes)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 2. Copy lockfile (changes when deps change)
COPY pyproject.toml uv.lock ./

# 3. Install deps (cached if lockfile unchanged)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-dev

# 4. Copy source (changes frequently)
COPY . .

# 5. Install project (quick, just links)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev
```

## Using uv-managed Python in Docker

```dockerfile
FROM ubuntu:24.04

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Let uv install Python (no base Python image needed)
RUN uv python install 3.12

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev
COPY . .

CMD ["uv", "run", "python", "-m", "my_app"]
```

## Compile Bytecode for Faster Startup

```dockerfile
# Pre-compile .pyc files for faster container startup
ENV UV_COMPILE_BYTECODE=1

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev
```

## Example Usage

```bash
# Build
docker build -t my-app .

# Run
docker run --rm my-app

# Build with cache export (for CI)
docker build --cache-from type=gha --cache-to type=gha -t my-app .
```

## See Also

- [ci-cd-integration](ci-cd-integration.md)
- [../concepts/installation](../concepts/installation.md)
