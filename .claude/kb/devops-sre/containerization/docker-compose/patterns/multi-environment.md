# Multi-Environment

> **Purpose**: Managing dev, staging, and production configurations with override files, profiles, and .env
> **MCP Validated**: 2026-02-19

## When to Use

- Running the same services with different configurations per environment
- Enabling optional services (monitoring, debugging) only when needed
- Separating development overrides from production defaults

## Implementation

### File Structure

```
project/
├── compose.yaml              # Base configuration (shared)
├── compose.override.yaml     # Dev overrides (auto-loaded)
├── compose.prod.yaml         # Production overrides
├── compose.test.yaml         # Test overrides
├── .env                      # Default variables (dev)
├── .env.prod                 # Production variables
└── secrets/
    └── db_password.txt
```

### Base Configuration

```yaml
# compose.yaml
services:
  api:
    build:
      context: ./api
    environment:
      APP_ENV: ${APP_ENV:-development}
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:${POSTGRES_VERSION:-16}-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

### Development Override (Auto-Loaded)

```yaml
# compose.override.yaml
services:
  api:
    build:
      target: development
    ports:
      - "8000:8000"
      - "5678:5678"
    volumes:
      - ./api/src:/app/src
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--reload"]
  db:
    ports:
      - "5432:5432"
```

### Production Override

```yaml
# compose.prod.yaml
services:
  api:
    build:
      target: production
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 1G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
  db:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/prod.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      api:
        condition: service_healthy
    restart: unless-stopped
```

### Environment Files

```bash
# .env (development defaults, auto-loaded)
COMPOSE_PROJECT_NAME=myapp-dev
APP_ENV=development
DB_NAME=myapp_dev
DB_USER=dev
DB_PASSWORD=devpassword

# .env.prod
COMPOSE_PROJECT_NAME=myapp-prod
APP_ENV=production
DB_NAME=myapp
DB_USER=myapp_user
DB_PASSWORD=${PROD_DB_PASSWORD}
```

## Running Different Environments

```bash
# Development (auto-loads compose.yaml + compose.override.yaml + .env)
docker compose up

# Production (skip override, use prod files)
docker compose -f compose.yaml -f compose.prod.yaml --env-file .env.prod up -d

# Testing
docker compose -f compose.yaml -f compose.test.yaml --env-file .env.test run --rm api pytest

# Validate merged configuration
docker compose -f compose.yaml -f compose.prod.yaml config
```

## Profiles for Optional Services

```yaml
services:
  adminer:
    image: adminer
    ports:
      - "8080:8080"
    profiles: [debug]
  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025:1025"
      - "8025:8025"
    profiles: [debug]
  prometheus:
    image: prom/prometheus
    profiles: [monitoring]
```

```bash
docker compose --profile debug up
COMPOSE_PROFILES=debug,monitoring docker compose up
```

## Configuration

| Variable | Purpose | Example |
|----------|---------|---------|
| `COMPOSE_FILE` | Override default file(s) | `compose.yaml:compose.prod.yaml` |
| `COMPOSE_PROFILES` | Active profiles | `debug,monitoring` |
| `COMPOSE_PROJECT_NAME` | Project namespace | `myapp-prod` |
| `COMPOSE_ENV_FILE` | Override default .env | `.env.prod` |

## See Also

- [production-deployment](production-deployment.md)
- [../concepts/environment](../concepts/environment.md)
- [../concepts/compose-file](../concepts/compose-file.md)
