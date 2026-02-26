# Compose File

> **Purpose**: Compose file structure, top-level elements, profiles, extensions, include, and interpolation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The Compose file (`compose.yaml`) is a declarative YAML specification for defining multi-container applications. Compose V2 uses the Compose Specification -- the `version:` key is officially deprecated and must be omitted from new files. Top-level elements include `services`, `networks`, `volumes`, `configs`, `secrets`, and `models` (2025+).

## The Pattern

```yaml
# compose.yaml -- no version key needed
services:
  api:
    build: ./api
    ports:
      - "8000:8000"
    profiles: [web]
  worker:
    image: myapp/worker:1.0
    profiles: [worker]
  db:
    image: postgres:16-alpine   # No profile = always started

networks:
  backend:

volumes:
  pgdata:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## File Discovery Order

| Priority | Filename | Purpose |
|----------|----------|---------|
| 1 | `compose.yaml` | Preferred default |
| 2 | `compose.yml` | Alternative default |
| 3 | `docker-compose.yaml` | Legacy compatibility |
| 4 | `docker-compose.yml` | Legacy compatibility |

Override file (auto-merged): `compose.override.yaml`

## Profiles

Profiles selectively enable services for different workflows:

```yaml
services:
  api:
    build: ./api         # No profile = always runs
  debug:
    image: busybox
    profiles: [debug]    # Only with --profile debug

# Start: docker compose --profile debug up
# Env:   COMPOSE_PROFILES=debug,test docker compose up
```

## Extensions (x- fields)

Reuse configuration fragments with YAML anchors:

```yaml
x-common-env: &common-env
  LOG_LEVEL: info
  APP_ENV: production

services:
  api:
    environment:
      <<: *common-env
      PORT: "8000"
  worker:
    environment:
      <<: *common-env
      WORKER_CONCURRENCY: "4"
```

## Include

```yaml
include:
  - path: ./infra/compose.yaml
  - path: ./monitoring/compose.yaml
```

## Models (2025+ -- AI Model Declarations)

Declare AI models as first-class citizens. Services reference models for inference:

```yaml
models:
  my-llm:
    model: ai/smollm2
    context_size: 2048

services:
  app:
    build: ./app
    models: [my-llm]          # Grant access; endpoint injected as env var
```

## Variable Interpolation

```yaml
services:
  api:
    image: ${REGISTRY:-docker.io}/myapp:${TAG:-latest}
    environment:
      DB_HOST: ${DB_HOST:?error: DB_HOST must be set}
```

| Syntax | Behavior |
|--------|----------|
| `${VAR}` | Substitute value, empty if unset |
| `${VAR:-default}` | Use default if unset or empty |
| `${VAR-default}` | Use default if unset only |
| `${VAR:?error}` | Error with message if unset or empty |

## Common Mistakes

### Wrong

```yaml
version: "3.8"       # Officially deprecated -- omit entirely
services:
  api:
    build: .
```

### Correct

```yaml
services:             # No version key -- officially deprecated since 2025
  api:
    build: .
```

## Related

- [services](services.md)
- [environment](environment.md)
- [../patterns/multi-environment](../patterns/multi-environment.md)
