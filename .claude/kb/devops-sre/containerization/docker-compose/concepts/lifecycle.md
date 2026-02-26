# Lifecycle

> **Purpose**: Container startup order, dependency conditions, healthchecks, and restart policies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docker Compose manages the lifecycle of containers from creation through shutdown. The `depends_on` directive with conditions controls startup ordering. Healthchecks define when a service is ready. Restart policies determine recovery behavior on failure.

## The Pattern

```yaml
services:
  migrate:
    build: ./api
    command: ["python", "manage.py", "migrate"]
    depends_on:
      db:
        condition: service_healthy

  api:
    build: ./api
    depends_on:
      db:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
```

## depends_on Conditions

| Condition | Waits Until | Use Case |
|-----------|-------------|----------|
| `service_started` | Container starts (default) | Loose coupling |
| `service_healthy` | Healthcheck passes | DB, cache readiness |
| `service_completed_successfully` | Container exits with code 0 | Migrations, init tasks |

```yaml
depends_on:
  db:
    condition: service_healthy
    restart: true                        # Restart if db restarts
  migrate:
    condition: service_completed_successfully
```

## Healthcheck Configuration

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s        # Time between checks
  timeout: 10s         # Max time for single check
  retries: 3           # Failures before "unhealthy"
  start_period: 40s    # Grace period on startup
  start_interval: 5s   # Interval during start_period
```

| Service | Healthcheck |
|---------|-------------|
| PostgreSQL | `pg_isready -U postgres` |
| MySQL | `mysqladmin ping -h localhost` |
| Redis | `redis-cli ping` |
| HTTP API | `curl -f http://localhost:PORT/health` |

## Restart Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `no` | Never restart (default) | One-off tasks |
| `always` | Always restart | Production services |
| `unless-stopped` | Restart unless manually stopped | Most services |
| `on-failure[:max]` | Restart on non-zero exit only | Workers |

## Stop and Shutdown

```yaml
services:
  api:
    stop_grace_period: 30s       # Time before SIGKILL (default: 10s)
    stop_signal: SIGQUIT         # Signal to send (default: SIGTERM)
  worker:
    init: true                   # Use tini as PID 1 for signal handling
    stop_grace_period: 60s
```

## Init Containers Pattern

```yaml
services:
  create-buckets:
    image: minio/mc
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 admin password;
      mc mb local/my-bucket --ignore-existing;
      "
  api:
    depends_on:
      create-buckets:
        condition: service_completed_successfully
```

## Common Mistakes

### Wrong

```yaml
depends_on:
  - db       # Only waits for container start, not readiness
```

### Correct

```yaml
depends_on:
  db:
    condition: service_healthy   # Waits for actual readiness
```

## Related

- [services](services.md)
- [networking](networking.md)
- [../patterns/database-services](../patterns/database-services.md)
