# Services

> **Purpose**: Define containers with image sources, build context, commands, and runtime configuration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Services are the core building block of a Compose application. Each service defines a container that Compose creates and manages. A service specifies which image to use (or how to build one), ports to expose, volumes to mount, environment variables, and dependencies on other services.

## The Pattern

```yaml
services:
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
      args:
        PYTHON_VERSION: "3.12"
    ports:
      - "8000:8000"
    volumes:
      - ./api/src:/app/src
    environment:
      DATABASE_URL: postgres://db:5432/myapp
    depends_on:
      db:
        condition: service_healthy

  worker:
    image: myapp/worker:1.2.0
    command: ["celery", "-A", "tasks", "worker", "--loglevel=info"]
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

volumes:
  pgdata:
```

## Image vs Build

| Approach | When to Use | Example |
|----------|-------------|---------|
| `image` | Pre-built image from registry | `image: nginx:1.27-alpine` |
| `build` | Custom image from Dockerfile | `build: ./api` |
| Both | Tag built image for pushing | `image: myapp:latest` + `build: .` |

## Build Configuration

```yaml
services:
  api:
    build:
      context: ./api              # Build context directory
      dockerfile: Dockerfile.dev  # Non-default Dockerfile
      target: development         # Multi-stage target
      args:
        PYTHON_VERSION: "3.12"    # Build arguments
      cache_from:
        - myapp:cache             # Cache sources
      platforms:
        - linux/amd64
        - linux/arm64
```

## Command and Entrypoint

```yaml
services:
  api:
    # Override Dockerfile CMD
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--reload"]

  worker:
    # Override Dockerfile ENTRYPOINT
    entrypoint: ["/custom-entrypoint.sh"]
    command: ["--mode", "worker"]
```

## Model Access (2025+)

Services can reference AI models declared in the top-level `models` section:

```yaml
services:
  agent:
    build: ./agent
    models:
      - my-llm          # Grants access; inference endpoint injected as env var
```

## Container Naming and Scaling

```yaml
services:
  api:
    container_name: myapp-api   # Fixed name (prevents scaling)

  worker:
    # No container_name = auto-named (project-service-N)
    # Allows: docker compose up --scale worker=3
    deploy:
      replicas: 3               # Alternative to --scale flag
```

## Common Mistakes

### Wrong

```yaml
services:
  api:
    build: .
    image: latest    # Meaningless tag
    ports:
      - 8000         # Random host port mapping
```

### Correct

```yaml
services:
  api:
    build: .
    image: myapp/api:1.0.0   # Meaningful tag for registry push
    ports:
      - "8000:8000"           # Explicit host:container mapping
```

## Related

- [compose-file](compose-file.md)
- [lifecycle](lifecycle.md)
- [../patterns/development-workflow](../patterns/development-workflow.md)
