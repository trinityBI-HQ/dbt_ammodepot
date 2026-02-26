# Environment

> **Purpose**: Environment variables, .env files, variable substitution, secrets, and configs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docker Compose provides multiple ways to inject configuration into services: inline `environment` maps, `env_file` references, `.env` files for Compose interpolation, and Docker secrets for sensitive data. Understanding the precedence order prevents unexpected overrides.

## The Pattern

```yaml
services:
  api:
    build: ./api
    environment:
      APP_ENV: production
      DATABASE_URL: postgres://db:5432/myapp
    env_file:
      - ./common.env
      - ./api.env
  worker:
    image: myapp/worker
    env_file:
      - path: ./worker.env
        required: false
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## Environment Precedence (Highest to Lowest)

| Priority | Source | Scope |
|----------|--------|-------|
| 1 | `docker compose run -e` | CLI override |
| 2 | Shell environment variables | Host shell |
| 3 | `environment` in compose file | Service-level |
| 4 | `--env-file` flag | CLI override of .env |
| 5 | `env_file` attribute | Service-level file |
| 6 | `.env` file | Compose interpolation only |

## The .env File

The `.env` file sets variables for Compose file interpolation (not passed to containers unless referenced):

```bash
# .env (auto-loaded by Compose from project directory)
COMPOSE_PROJECT_NAME=myapp
POSTGRES_VERSION=16
APP_IMAGE_TAG=1.2.0
```

```yaml
services:
  db:
    image: postgres:${POSTGRES_VERSION}-alpine
  api:
    image: myapp/api:${APP_IMAGE_TAG}
```

## env_file Format

```bash
# api.env -- comments and blank lines are ignored
APP_PORT=8000
LOG_LEVEL=info
```

```yaml
services:
  api:
    env_file:
      - path: ./base.env
        required: true          # Default: fail if missing
      - path: ./local.env
        required: false         # Skip silently if missing
```

## Docker Secrets

For sensitive data, use secrets instead of environment variables:

```yaml
services:
  api:
    secrets:
      - db_password
      - api_key
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    environment: MY_API_KEY       # From host env var
```

Application reads `/run/secrets/db_password` at runtime:

```python
from pathlib import Path

def get_secret(name: str) -> str:
    secret_path = Path(f"/run/secrets/{name}")
    return secret_path.read_text().strip() if secret_path.exists() else ""
```

## Common Mistakes

### Wrong

```yaml
services:
  api:
    environment:
      DB_PASSWORD: supersecret123   # Secret in plain text
```

### Correct

```yaml
services:
  api:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt   # File in .gitignore
```

## Related

- [compose-file](compose-file.md)
- [services](services.md)
- [../patterns/multi-environment](../patterns/multi-environment.md)
