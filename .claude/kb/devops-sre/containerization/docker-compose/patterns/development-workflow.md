# Development Workflow

> **Purpose**: Local development with hot reload, watch mode, debugging, and override files
> **MCP Validated**: 2026-02-19

## When to Use

- Setting up local multi-service development environments
- Enabling hot reload without rebuilding containers
- Debugging containerized applications with IDE integration
- Running tests inside containers with the same environment as CI

## Implementation

```yaml
# compose.yaml -- base configuration
services:
  api:
    build:
      context: ./api
      target: development
    ports:
      - "8000:8000"
      - "5678:5678"          # Debug port (debugpy)
    volumes:
      - ./api/src:/app/src   # Source code bind mount
    environment:
      APP_ENV: development
      PYTHONDONTWRITEBYTECODE: 1
    depends_on:
      db:
        condition: service_healthy
    develop:
      watch:
        - action: sync
          path: ./api/src
          target: /app/src
        - action: rebuild
          path: ./api/pyproject.toml
        - action: sync+restart
          path: ./api/config
          target: /app/config

  frontend:
    build:
      context: ./frontend
      target: development
    ports:
      - "3000:3000"
    develop:
      watch:
        - action: sync
          path: ./frontend/src
          target: /app/src
        - action: rebuild
          path: ./frontend/package.json

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: devpassword
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dev"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

## Watch Mode Actions

| Action | Behavior | Use Case |
|--------|----------|----------|
| `sync` | Copy changed files into container | Source code (hot reload by app) |
| `rebuild` | Rebuild image and recreate container | Dependency changes (package.json, pyproject.toml) |
| `sync+restart` | Sync files, then restart container | Config files that need process restart |

```bash
# Start watch mode
docker compose watch

# Watch with build + detach
docker compose watch --no-up    # Watch only, don't start
docker compose up -d && docker compose watch  # Background + watch
```

## Override Files for Development

```yaml
# compose.override.yaml -- auto-merged with compose.yaml
services:
  api:
    build:
      target: development       # Use dev stage of multi-stage Dockerfile
    volumes:
      - ./api/src:/app/src      # Bind mount for live editing
    environment:
      DEBUG: "true"
      LOG_LEVEL: debug
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--reload"]

  db:
    ports:
      - "5432:5432"             # Expose DB port for local tools
```

## Debugging with debugpy (Python)

```dockerfile
# api/Dockerfile
FROM python:3.12-slim AS development
RUN pip install debugpy
COPY . /app
WORKDIR /app
CMD ["python", "-m", "debugpy", "--listen", "0.0.0.0:5678", "--wait-for-client", \
     "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--reload"]
```

```yaml
# compose.yaml
services:
  api:
    build:
      context: ./api
      target: development
    ports:
      - "8000:8000"
      - "5678:5678"     # Attach VS Code debugger here
```

VS Code `launch.json`:

```json
{
  "name": "Attach to Docker",
  "type": "debugpy",
  "request": "attach",
  "connect": { "host": "localhost", "port": 5678 },
  "pathMappings": [
    { "localRoot": "${workspaceFolder}/api/src", "remoteRoot": "/app/src" }
  ]
}
```

## Running Tests

```bash
# One-off test run (creates temporary container)
docker compose run --rm api pytest tests/ -v

# Run with specific env
docker compose run --rm -e APP_ENV=test api pytest

# Interactive shell for debugging
docker compose exec api bash
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `develop.watch[].action` | Required | `sync`, `rebuild`, or `sync+restart` |
| `develop.watch[].path` | Required | Host path to monitor |
| `develop.watch[].target` | Same as path | Container path for sync |
| `develop.watch[].ignore` | `[]` | Paths to exclude from watching |

## AI Model Development (2025+)

For agentic AI apps (CrewAI, LangGraph), use the `models` section with watch:

```yaml
models:
  local-llm:
    model: ai/smollm2

services:
  agent:
    build: ./agent
    models:
      - local-llm
    develop:
      watch:
        - action: sync
          path: ./agent/src
          target: /app/src
```

## See Also

- [multi-environment](multi-environment.md)
- [../concepts/volumes](../concepts/volumes.md)
- [../concepts/compose-file](../concepts/compose-file.md)
